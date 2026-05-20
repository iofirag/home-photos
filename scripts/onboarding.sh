#!/bin/bash

set -e

WIFI_CONNECT_NAME="wifi-connect"
CHECK_URL="https://clients3.google.com/generate_204"
RESET_NETWORK_DELAY=30
INTERVAL=5
SERVER_URL="10.0.0.114:5000" # "aghaiofir.win"
CLIENT_TEMPLATE_ARCHIVE="client-template-files.tar.gz"
CLIENT_APP_DIR="/client-app"
PROVISION_MARKER="$CLIENT_APP_DIR/.provisioned"
POSTGRES_UID="999"
POSTGRES_GID="999"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

internet_ok() {
  curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$CHECK_URL" | grep -q "204"
}

start_hotspot() {
  if docker ps --format '{{.Names}}' | grep -q "$WIFI_CONNECT_NAME"; then
    log "Hotspot already running"
    return
  fi

  log "Starting WiFi hotspot (wifi-connect)..."
  docker run -it --rm \
    --name "$WIFI_CONNECT_NAME" \
    --network host \
    --privileged \
    -v /var/run/dbus:/host/run/dbus \
    "$WIFI_CONNECT_NAME" &
}

stop_hotspot() {
  if docker ps --format '{{.Names}}' | grep -q "$WIFI_CONNECT_NAME"; then
    log "Stopping WiFi hotspot..."
    docker stop "$WIFI_CONNECT_NAME" || true
    docker rm "$WIFI_CONNECT_NAME" || true
  else
    log "WiFi hotspot is not running"
  fi
}

# claim_device() {
#   log "Internet available → running claim process"

#   # Replace this with your real onboarding logic
#   curl -X POST "https://your-server.com/device/claim" \
#     -H "Content-Type: application/json" \
#     -d "{\"device_id\": \"$(cat /etc/machine-id 2>/dev/null || hostname)\"}" \
#     || log "Claim request failed"
# }

download_application_files() {
  log "Downloading application files..."
  curl -fL -o "$CLIENT_TEMPLATE_ARCHIVE" "http://${SERVER_URL%/}/download-client-template-files"
  log "Extracting application files..."
  sudo mkdir -p "$CLIENT_APP_DIR"
  sudo tar -xzf "$CLIENT_TEMPLATE_ARCHIVE" -C "$CLIENT_APP_DIR" --strip-components=1
  sudo chown -R "$(id -u):$(id -g)" "$CLIENT_APP_DIR"
  rm -f "$CLIENT_TEMPLATE_ARCHIVE"
}

create_client_tunnel() {
  # get mac address
  MAC_ADDRESS=$(ip link show | awk '/ether/ {print $2}' | head -n 1)
  DEVICE_ID=$(printf '%s' "$MAC_ADDRESS" | tr ':' '-')
  ENV_EXAMPLE_FILE="$CLIENT_APP_DIR/.env.example"
  ENV_FILE="$CLIENT_APP_DIR/.env"
  RESPONSE_FILE=$(mktemp)

  log "Creating client tunnel with MAC address: $MAC_ADDRESS"
  curl -fsS -X POST "http://${SERVER_URL%/}/create-client-tunnel" \
    -H "Content-Type: application/json" \
    -d "{\"device_id\": \"$DEVICE_ID\"}" \
    -o "$RESPONSE_FILE" \
    || { rm -f "$RESPONSE_FILE"; log "Create client tunnel request failed"; return 1; }

  if [ ! -f "$ENV_EXAMPLE_FILE" ]; then
    rm -f "$RESPONSE_FILE"
    log "Missing env example file: $ENV_EXAMPLE_FILE"
    return 1
  fi

  cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
  if [ -s "$ENV_FILE" ]; then
    printf '\n' >> "$ENV_FILE"
  fi
  tr -d '{}"' < "$RESPONSE_FILE" \
    | awk -v RS=',' '{
        separator=index($0, ":")
        if (separator == 0) next
        key=substr($0, 1, separator - 1)
        value=substr($0, separator + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        if (key != "") print key "=" value
      }' \
    >> "$ENV_FILE"
  rm -f "$RESPONSE_FILE"
}

prepare_app_data() {
  log "Preparing application data directories..."
  sudo mkdir -p \
    "$CLIENT_APP_DIR/client-data/immich/library" \
    "$CLIENT_APP_DIR/client-data/immich/postgres" \
    "$CLIENT_APP_DIR/client-data/immichframe/Config"

  sudo chown -R "$POSTGRES_UID:$POSTGRES_GID" "$CLIENT_APP_DIR/client-data/immich/postgres"
}

start_app() {
  log "Starting application..."
  if [ ! -d "$CLIENT_APP_DIR" ]; then
    log "Client app directory not found: $CLIENT_APP_DIR"
    return 1
  fi
  prepare_app_data
  (
    cd "$CLIENT_APP_DIR"
    sudo docker compose up -d
  )
}

reset_network() {
  log "Resetting wifi network"
  # Add any necessary commands to reset the network here
  sudo systemctl restart NetworkManager || log "Failed to restart NetworkManager"
  nmcli radio wifi on || log "Failed to turn wifi on"
}

if ! internet_ok; then
  reset_network
  sleep "$RESET_NETWORK_DELAY"
fi

log "Starting provisioning loop..."
while true; do
  if internet_ok; then
    log "Internet detected"
    stop_hotspot
    # claim_device
    if [ ! -f "$PROVISION_MARKER" ]; then
      download_application_files
      create_client_tunnel
      start_app
      touch "$PROVISION_MARKER"
    else
      log "App already provisioned; skipping setup"
    fi
  else
    log "No internet detected - starting hotspot"
    start_hotspot
  fi

  sleep "$INTERVAL"
done