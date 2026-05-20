import re
import json
import shutil
import requests
from pathlib import Path
from config import settings


BASE_URL = "https://api.cloudflare.com/client/v4"
DEVICE_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")

HEADERS = {
    "Authorization": f"Bearer {settings.cloudflare_api_token}",
    "Content-Type": "application/json",
}


def validate_device_id(device_id: str) -> str | None:
    if not device_id:
        return "device_id is required"

    if not DEVICE_ID_PATTERN.fullmatch(device_id):
        return "device_id may only contain letters, numbers, underscores, and hyphens"

    return None


def cloudflare_request(method: str, url: str, payload: dict | None = None) -> dict:
    response = requests.request(
        method=method,
        url=url,
        headers=HEADERS,
        json=payload,
        timeout=30,
    )

    try:
        data = response.json()
    except ValueError:
        raise RuntimeError(f"Cloudflare returned non-JSON response: {response.text}")

    if not response.ok or not data.get("success", False):
        raise RuntimeError(
            json.dumps(
                {
                    "status_code": response.status_code,
                    "url": url,
                    "response": data,
                },
                indent=2,
            )
        )

    return data


def create_remote_tunnel(device_id: str) -> tuple[str, str]:
    tunnel_name = device_id
    url = f"{BASE_URL}/accounts/{settings.cloudflare_account_id}/cfd_tunnel"

    payload = {
        "name": tunnel_name,
        "config_src": "cloudflare",
    }

    data = cloudflare_request("POST", url, payload)

    tunnel_id = data["result"]["id"]
    tunnel_token = data["result"]["token"]

    return tunnel_id, tunnel_token


def configure_tunnel_ingress(tunnel_id: str, device_id: str) -> None:
    url = f"{BASE_URL}/accounts/{settings.cloudflare_account_id}/cfd_tunnel/{tunnel_id}/configurations"

    payload = {
        "config": {
            "ingress": [
                {
                    "hostname": f"ssh-{device_id}.{settings.base_domain}",
                    "service": "ssh://host.docker.internal:22",
                },
                {
                    "hostname": f"photos-{device_id}.{settings.base_domain}",
                    "service": "http://caddy:80",
                },
                {
                    "hostname": f"health-{device_id}.{settings.base_domain}",
                    "service": "http://caddy:80",
                },
                {
                    "service": "http_status:404",
                },
            ]
        }
    }

    cloudflare_request("PUT", url, payload)


def get_existing_dns_record(hostname: str) -> dict | None:
    url = f"{BASE_URL}/zones/{settings.cloudflare_zone_id}/dns_records"

    params = {
        "type": "CNAME",
        "name": hostname,
    }

    response = requests.get(
        url,
        headers=HEADERS,
        params=params,
        timeout=30,
    )

    data = response.json()

    if not response.ok or not data.get("success", False):
        raise RuntimeError(json.dumps(data, indent=2))

    records = data.get("result", [])

    if not records:
        return None

    return records[0]


def create_or_update_dns_record(subdomain: str, tunnel_id: str, device_id: str) -> None:
    hostname = f"{subdomain}-{device_id}.{settings.base_domain}"
    record_name = f"{subdomain}-{device_id}"
    target = f"{tunnel_id}.cfargotunnel.com"

    existing = get_existing_dns_record(hostname)

    payload = {
        "type": "CNAME",
        "name": record_name,
        "content": target,
        "proxied": True,
    }

    if existing:
        record_id = existing["id"]
        url = f"{BASE_URL}/zones/{settings.cloudflare_zone_id}/dns_records/{record_id}"
        cloudflare_request("PUT", url, payload)
    else:
        url = f"{BASE_URL}/zones/{settings.cloudflare_zone_id}/dns_records"
        cloudflare_request("POST", url, payload)


def create_dns_records(tunnel_id: str, device_id: str) -> None:
    for subdomain in ["ssh", "photos", "health"]:
        create_or_update_dns_record(subdomain, tunnel_id, device_id)


def create_client_tunnel(device_id: str) -> dict:
    tunnel_id, tunnel_token = create_remote_tunnel(device_id)
    configure_tunnel_ingress(tunnel_id, device_id)
    create_dns_records(tunnel_id, device_id)
    return {
        "device_id": device_id,
        "tunnel_id": tunnel_id,
        "tunnel_token": tunnel_token,
        # "package_dir": str(package_dir),
        "client_urls": {
            "photos": f"https://photos-{device_id}.{settings.base_domain}",
            "health": f"https://health-{device_id}.{settings.base_domain}",
            "ssh": f"ssh-{device_id}.{settings.base_domain}",
        },
    }






# def generate_client_package(tunnel_token: str, device_id: str) -> Path:
#     package_dir = Path("packages") / device_id
#     if package_dir.exists():
#         shutil.rmtree(package_dir)

#     shutil.copytree(Path("client-template-files"), package_dir)

#     extra_env_content = f"""

# # =========================
# # Client
# # =========================
# DEVICE_ID={device_id}

# # =========================
# # Cloudflare
# # =========================
# CLOUDFLARE_TUNNEL_TOKEN={tunnel_token}
# BASE_DOMAIN={settings.base_domain}
# """
#     env_file = package_dir / ".env"
#     with env_file.open("a", encoding="utf-8") as f:
#         f.write(extra_env_content)

#     return package_dir