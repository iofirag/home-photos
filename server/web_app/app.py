from flask import Flask, redirect, url_for, session, request
from authlib.integrations.flask_client import OAuth
import os

# Initialize Flask app
app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "secret")
app.config['GOOGLE_CLIENT_ID'] = os.getenv("GOOGLE_CLIENT_ID")
app.config['GOOGLE_CLIENT_SECRET'] = os.getenv("GOOGLE_CLIENT_SECRET")
app.config['GOOGLE_DISCOVERY_URL'] = (
    "https://accounts.google.com/.well-known/openid-configuration"
)

# Initialize OAuth
oauth = OAuth(app)
google = oauth.register(
    name="google",
    client_id=app.config['GOOGLE_CLIENT_ID'],
    client_secret=app.config['GOOGLE_CLIENT_SECRET'],
    server_metadata_url=app.config['GOOGLE_DISCOVERY_URL'],
    client_kwargs={"scope": "openid email profile"},
)

# Data for user devices (simulate a database)
USER_DEVICES = {
    "user@example.com": ["Device 1", "Device 2", "Smartphone"],
}

@app.route("/")
def index():
    user = dict(session).get("profile", None)
    return f"Welcome {user['name']}!" if user else 'Welcome! <a href="/login">Log in</a>'

@app.route("/login")
def login():
    return google.authorize_redirect(url_for("callback", _external=True))

@app.route("/callback")
def callback():
    token = google.authorize_access_token()
    user = google.parse_id_token(token)
    session["profile"] = user
    return redirect(url_for("devices"))

@app.route("/devices")
def devices():
    user = dict(session).get("profile", None)
    if not user:
        return redirect(url_for("login"))
    email = user.get("email")
    devices = USER_DEVICES.get(email, [])
    return f"<h1>Devices for {user['name']}</h1><ul>{''.join(f'<li>{d}</li>' for d in devices)}</ul>"

if __name__ == "__main__":
    app.run(debug=True)