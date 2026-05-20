#!/bin/bash

set -e

WIFI_CONNECT_NAME="wifi-connect"
CHECK_URL="https://clients3.google.com/generate_204"
RESET_NETWORK_DELAY=30
INTERVAL=5

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

claim_device() {
  log "Internet available → running claim process"

  # Replace this with your real onboarding logic
  curl -X POST "https://your-server.com/device/claim" \
    -H "Content-Type: application/json" \
    -d "{\"device_id\": \"$(cat /etc/machine-id 2>/dev/null || hostname)\"}" \
    || log "Claim request failed"
}

download_application_files() {
  
}

reset_network() {
  log "Resetting wifi network"
  # Add any necessary commands to reset the network here
  sudo systemctl restart NetworkManager || log "Failed to restart NetworkManager"
  nmcli radio wifi on || log "Failed to turn wifi on"
}

reset_network
sleep "$RESET_NETWORK_DELAY"

log "Starting provisioning loop..."
while true; do
  if internet_ok; then
    log "Internet detected"
    stop_hotspot
    claim_device
  else
    log "No internet detected - starting hotspot"
    start_hotspot
  fi

  sleep "$INTERVAL"
done