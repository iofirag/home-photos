from flask import Flask, render_template, request, jsonify
import requests

app = Flask(__name__)

@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/albums", methods=["POST"])
def get_albums():
    data = request.json

    server_url = data.get("server_url", "http://localhost:2283")
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


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)