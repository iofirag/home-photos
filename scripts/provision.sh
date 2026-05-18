#!/bin/bash

set -e

WIFI_CONNECT_NAME="wifi-connect"
CHECK_URL="https://clients3.google.com/generate_204"
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

#   log "Starting WiFi hotspot (wifi-connect)..."
#   docker run -d \
#     --restart unless-stopped \
#     --net=host \
#     --privileged \
#     --name "$WIFI_CONNECT_NAME" \
#     balenablocks/wifi-connect:aarch64

  log "Starting WiFi hotspot (wifi-connect)..."  
  echo "Starting wifi-connect..."
  docker run --rm -it \
    --name "$WIFI_CONNECT_NAME" \
    --network host \
    --privileged \
    -v /var/run/dbus:/host/run/dbus \
    "$WIFI_CONNECT_NAME"
}

stop_hotspot() {
  if docker ps --format '{{.Names}}' | grep -q "$WIFI_CONNECT_NAME"; then
    log "Stopping WiFi hotspot..."
    docker stop "$WIFI_CONNECT_NAME" || true
    docker rm "$WIFI_CONNECT_NAME" || true
  fi
}

claim_device() {
  log "Internet available → running claim process"

  # 🔽 Replace this with your real onboarding logic
  # Example: call your backend
  curl -X POST "https://your-server.com/device/claim" \
    -H "Content-Type: application/json" \
    -d "{\"device_id\": \"$(cat /etc/machine-id 2>/dev/null || hostname)\"}" \
    || log "Claim request failed"
}

log "Starting provisioning loop..."

while true; do
  if internet_ok; then
    log "Internet detected"
    stop_hotspot
    claim_device
  else
    log "No internet detected"
    start_hotspot
  fi

  sleep "$INTERVAL"
done