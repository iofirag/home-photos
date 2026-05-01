#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${DATA_DIR:-/mnt/client-data}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Using project dir: $PROJECT_DIR"
echo "Using data dir: $DATA_DIR"

# Create main folders
mkdir -p "$DATA_DIR/immich/library"
mkdir -p "$DATA_DIR/immich/postgres"

mkdir -p "$DATA_DIR/caddy/data"
mkdir -p "$DATA_DIR/caddy/config"

mkdir -p "$DATA_DIR/cloudflared"

# mkdir -p "$DATA_DIR/immichframe/Config"

# Copy Caddyfile only if missing
if [ ! -f "$DATA_DIR/caddy/Caddyfile" ]; then
  echo "Creating Caddyfile..."
  cp "$PROJECT_DIR/templates/caddy/Caddyfile" "$DATA_DIR/caddy/Caddyfile"
else
  echo "Caddyfile already exists, skipping."
fi

# Copy cloudflared config only if missing
if [ ! -f "$DATA_DIR/cloudflared/config.yaml" ]; then
  echo "Creating cloudflared config.yaml..."
  cp "$PROJECT_DIR/templates/cloudflared/config.yaml" "$DATA_DIR/cloudflared/config.yaml"
else
  echo "cloudflared config.yaml already exists, skipping."
fi

# Copy cloudflared tunnel.json only if missing
if [ ! -f "$DATA_DIR/cloudflared/tunnel.json" ]; then
  echo "Creating cloudflared tunnel.json..."
  cp "$PROJECT_DIR/templates/cloudflared/tunnel.json" "$DATA_DIR/cloudflared/tunnel.json"
else
  echo "cloudflared tunnel.json already exists, skipping."
fi

# # Copy ImmichFrame config only if missing
# if [ ! -f "$DATA_DIR/immichframe/Config/Settings.yaml" ]; then
#   echo "Creating ImmichFrame Settings.yaml..."
#   cp "$PROJECT_DIR/templates/immichframe/Config/Settings.yaml" "$DATA_DIR/immichframe/Config/Settings.yaml"
# else
#   echo "ImmichFrame Settings.yaml already exists, skipping."
# fi

# Permissions
CURRENT_UID="${SUDO_UID:-$(id -u)}"
CURRENT_GID="${SUDO_GID:-$(id -g)}"

sudo chown -R "$CURRENT_UID:$CURRENT_GID" "$DATA_DIR"

echo ""
echo "Init completed."
echo "Data folder is ready at: $DATA_DIR"