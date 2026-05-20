import sys

from cloudflare_service import create_client_tunnel, validate_device_id


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: py client-tunnel-creation.py <device_id>")
        sys.exit(1)

    device_id = sys.argv[1].strip()
    validation_error = validate_device_id(device_id)

    if validation_error:
        print(f"Error: {validation_error}")
        sys.exit(1)

    print("Hello from home-photos server!")

    result = create_client_tunnel(device_id)

    print()
    print("Done.")
    print(f"Tunnel ID: {result['tunnel_id']}")
    print(f"Tunnel Token: {result['tunnel_token']}")
    print("Client URLs:")
    print(f"  {result['client_urls']['photos']}")
    print(f"  {result['client_urls']['health']}")
    print(f"  {result['client_urls']['ssh']}")


if __name__ == "__main__":
    main()
