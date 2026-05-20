import os
import tarfile
from flask import Flask, json, send_file, jsonify, request
from config import settings
from cloudflare_service import create_client_tunnel, validate_device_id


def get_device_id_from_request() -> str | None:
    data = request.get_json(silent=True) or {}
    return (data.get("device_id") or request.form.get("device_id") or request.args.get("device_id") or "").strip()


def create_app():
    app = Flask(__name__)

    @app.route('/')
    def main_page():
        return jsonify({"message": "Welcome to the Main Page!"})

    @app.route('/download-client-template-files')
    def download_client_app():
        tar_path = "./cache/client-template-files.tar.gz"
        template_dir = "./client-template-files"

        os.makedirs(os.path.dirname(tar_path), exist_ok=True)

        try:
            with tarfile.open(tar_path, "w:gz") as tar:
                tar.add(template_dir, arcname="client-template-files")
        except Exception as e:
            return jsonify({"error": f"Failed to create tar.gz: {str(e)}"}), 500

        # Send the tar.gz file
        try:
            return send_file(tar_path, as_attachment=True)
        except FileNotFoundError:
            return jsonify({"error": "File not found."}), 404

    @app.route('/create-client-tunnel', methods=['POST'])
    def client_tunnel_creation():
        device_id = get_device_id_from_request()
        validation_error = validate_device_id(device_id)

        if validation_error:
            return jsonify({"error": validation_error}), 400

        try:
            result = create_client_tunnel(device_id)
            # print result json
            print(json.dumps(result, indent=2))
            return {
                "DEVICE_ID": result["device_id"],
                "BASE_DOMAIN": settings.base_domain,
                "CLOUDFLARE_TUNNEL_TOKEN": result["tunnel_token"],
            }, 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    return app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000)