from flask import Flask, render_template, request, jsonify
from pathlib import Path
import requests
import os
import docker

app = Flask(__name__)


def restart_immichframe_container():
    client = docker.from_env()
    container_name = os.getenv("IMMICHFRAME_CONTAINER_NAME", "immichframe")
    container = client.containers.get(container_name)
    container.restart()
    return container_name


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/albums", methods=["POST"])
def get_albums():
    data = request.json

    server_url = os.getenv("IMMICH_SERVER_URL", "http://localhost:2283")
    api_key = data.get("api_key")

    try:
        headers = {
            "x-api-key": api_key
        }

        response = requests.get(
            f"{server_url}/api/albums",
            headers=headers
        )

        return (response.text, response.status_code, {'Content-Type': 'application/json'})

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# @app.route("/api/thumbnail", methods=["GET"])
# def get_thumbnail():
#     server_url = request.args.get("server_url")
#     api_key = request.args.get("api_key")
#     asset_id = request.args.get("asset_id")

#     if not server_url or not api_key or not asset_id:
#         return jsonify({"error": "server_url, api_key, and asset_id are required"}), 400

#     try:
#         headers = {
#             "x-api-key": api_key
#         }

#         response = requests.get(
#             f"{server_url}/api/assets/{asset_id}/thumbnail",
#             headers=headers
#         )

#         if response.status_code != 200:
#             return jsonify({"error": f"Failed to fetch thumbnail: {response.status_code}"}), response.status_code

#         return response.content, response.status_code, {'Content-Type': response.headers.get('Content-Type', 'image/jpeg')}

#     except Exception as e:
#         return jsonify({"error": str(e)}), 500


@app.route("/create-immich-configuration", methods=["POST"])
def create_immich_configuration():
    data = request.json or {}

    server_url = data.get("server_url") or os.getenv("IMMICH_SERVER_URL", "http://immich-server:2283")
    api_key = data.get("api_key")
    album_ids = data.get("album_ids", [])

    if not api_key:
        return jsonify({"error": "api_key is required"}), 400

    if not isinstance(album_ids, list):
        return jsonify({"error": "album_ids must be a list"}), 400

    try:

        base_dir = Path(__file__).resolve().parent
        template_path = base_dir / "templates" / "immichframe" / "config" / "Settings.yaml"
        
        # Use environment variable for output directory, fallback to parent/client-data
        config_output_dir = os.getenv("IMMICHFRAME_CONFIG_DIR")
        if config_output_dir:
            output_dir = Path(config_output_dir)
        else:
            output_dir = base_dir.parent / "client-data" / "immichframe" / "Config"
        
        output_dir.mkdir(parents=True, exist_ok=True)
        output_path = output_dir / "Settings.yaml"

        with open(template_path, "r", encoding="utf-8") as template_file:
            lines = template_file.readlines()

        output_lines = []
        skip_album_section = False
        for line in lines:
            stripped = line.strip()
            if line.lstrip().startswith("ImmichServerUrl:"):
                output_lines.append(f'    ImmichServerUrl: "{server_url}"\n')
                continue
            if line.lstrip().startswith("ApiKey:"):
                output_lines.append(f'    ApiKey: "{api_key}"\n')
                continue
            if stripped == "# Albums:":
                if album_ids:
                    output_lines.append("    Albums:\n")
                    for album_id in album_ids:
                        output_lines.append(f'      - "{album_id}"\n')
                skip_album_section = True
                continue
            if skip_album_section:
                if stripped.startswith("#") or stripped == "":
                    continue
                skip_album_section = False

            output_lines.append(line)

        with open(output_path, "w", encoding="utf-8") as output_file:
            output_file.writelines(output_lines)

        # Restart immichframe container
        try:
            restart_immichframe_container()
        except Exception as restart_error:
            return jsonify({
                "success": False,
                "error": f"Config created but failed to restart immichframe: {str(restart_error)}"
            }), 500

        return jsonify({
            "success": True,
            "message": f"Created configuration at {output_path} and restarted immichframe",
            "path": str(output_path),
            "album_ids": album_ids
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500
    

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081, debug=True)