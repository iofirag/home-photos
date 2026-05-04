#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="/opt/client-stack"
ENV_FILE="$STACK_DIR/.env"
CLOUDFLARED_DIR="$STACK_DIR/cloudflared"
CONFIG_TEMPLATE="$CLOUDFLARED_DIR/config.yaml.template"
CONFIG_FILE="$CLOUDFLARED_DIR/config.yaml"
TUNNEL_JSON="$CLOUDFLARED_DIR/tunnel.json"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "ERROR: cloudflared is not installed on this machine."
  echo "Install cloudflared first, then run this script again."
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: Missing $ENV_FILE"
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

if [ -z "${DEVICE_ID:-}" ]; then
  echo "ERROR: DEVICE_ID is missing in .env"
  exit 1
fi

if [ -z "${BASE_DOMAIN:-}" ]; then
  echo "ERROR: BASE_DOMAIN is missing in .env"
  exit 1
fi

TUNNEL_NAME="${TUNNEL_NAME:-device-${DEVICE_ID}}"

mkdir -p "$CLOUDFLARED_DIR"

echo "Using:"
echo "  DEVICE_ID=$DEVICE_ID"
echo "  BASE_DOMAIN=$BASE_DOMAIN"
echo "  TUNNEL_NAME=$TUNNEL_NAME"
echo

echo "Checking Cloudflare login..."
if ! cloudflared tunnel list >/dev/null 2>&1; then
  echo "You are not logged in to Cloudflare."
  echo "Running: cloudflared tunnel login"
  cloudflared tunnel login
fi

echo
echo "Checking if tunnel already exists..."

EXISTING_TUNNEL_ID="$(
  cloudflared tunnel list 2>/dev/null \
    | awk -v name="$TUNNEL_NAME" '$2 == name {print $1; exit}'
)"

if [ -n "$EXISTING_TUNNEL_ID" ]; then
  TUNNEL_ID="$EXISTING_TUNNEL_ID"
  echo "Tunnel already exists:"
  echo "  $TUNNEL_NAME -> $TUNNEL_ID"
else
  echo "Creating tunnel: $TUNNEL_NAME"

  CREATE_OUTPUT="$(cloudflared tunnel create "$TUNNEL_NAME")"
  echo "$CREATE_OUTPUT"

  TUNNEL_ID="$(
    cloudflared tunnel list 2>/dev/null \
      | awk -v name="$TUNNEL_NAME" '$2 == name {print $1; exit}'
  )"

  if [ -z "$TUNNEL_ID" ]; then
    echo "ERROR: Tunnel was created but could not detect tunnel ID."
    echo "Run manually:"
    echo "  cloudflared tunnel list"
    exit 1
  fi
fi

SOURCE_JSON="$HOME/.cloudflared/$TUNNEL_ID.json"

if [ ! -f "$SOURCE_JSON" ]; then
  echo "ERROR: Tunnel credentials file not found:"
  echo "  $SOURCE_JSON"
  echo
  echo "Expected after:"
  echo "  cloudflared tunnel create $TUNNEL_NAME"
  exit 1
fi

echo
echo "Copying tunnel credentials..."
cp "$SOURCE_JSON" "$TUNNEL_JSON"
chmod 600 "$TUNNEL_JSON"

echo
echo "Creating DNS routes..."

cloudflared tunnel route dns "$TUNNEL_NAME" "photos-${DEVICE_ID}.${BASE_DOMAIN}" || true
cloudflared tunnel route dns "$TUNNEL_NAME" "health-${DEVICE_ID}.${BASE_DOMAIN}" || true
cloudflared tunnel route dns "$TUNNEL_NAME" "ssh-${DEVICE_ID}.${BASE_DOMAIN}" || true

echo
echo "Creating cloudflared config template if missing..."

if [ ! -f "$CONFIG_TEMPLATE" ]; then
  cat > "$CONFIG_TEMPLATE" <<'EOF'
tunnel: ${CLOUDFLARE_TUNNEL_ID}
credentials-file: /etc/cloudflared/tunnel.json

ingress:
  - hostname: ssh-${DEVICE_ID}.${BASE_DOMAIN}
    service: ssh://host.docker.internal:22

  - hostname: photos-${DEVICE_ID}.${BASE_DOMAIN}
    service: http://caddy:80

  - hostname: health-${DEVICE_ID}.${BASE_DOMAIN}
    service: http://caddy:80

  - service: http_status:404
EOF
fi

echo
echo "Rendering cloudflared config..."

export CLOUDFLARE_TUNNEL_ID="$TUNNEL_ID"

if command -v envsubst >/dev/null 2>&1; then
  envsubst < "$CONFIG_TEMPLATE" > "$CONFIG_FILE"
else
  sed \
    -e "s|\${CLOUDFLARE_TUNNEL_ID}|$CLOUDFLARE_TUNNEL_ID|g" \
    -e "s|\${DEVICE_ID}|$DEVICE_ID|g" \
    -e "s|\${BASE_DOMAIN}|$BASE_DOMAIN|g" \
    "$CONFIG_TEMPLATE" > "$CONFIG_FILE"
fi

chmod 644 "$CONFIG_FILE"

echo
echo "Updating .env with CLOUDFLARE_TUNNEL_ID..."

if grep -q '^CLOUDFLARE_TUNNEL_ID=' "$ENV_FILE"; then
  sed -i.bak "s|^CLOUDFLARE_TUNNEL_ID=.*|CLOUDFLARE_TUNNEL_ID=$TUNNEL_ID|" "$ENV_FILE"
else
  printf '\nCLOUDFLARE_TUNNEL_ID=%s\n' "$TUNNEL_ID" >> "$ENV_FILE"
fi

echo
echo "Done."
echo
echo "Created/updated:"
echo "  $TUNNEL_JSON"
echo "  $CONFIG_FILE"
echo
echo "DNS hostnames:"
echo "  https://photos-${DEVICE_ID}.${BASE_DOMAIN}"
echo "  https://health-${DEVICE_ID}.${BASE_DOMAIN}"
echo "  ssh-${DEVICE_ID}.${BASE_DOMAIN}"
echo
echo "Next run:"
echo "  cd $STACK_DIR"
echo "  docker compose up -d --force-recreate cloudflared"
echo "  docker logs -f cloudflared"