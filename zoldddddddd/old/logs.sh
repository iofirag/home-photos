#!/usr/bin/env bash
set -e

cd /opt/client-stack

SERVICE="${1:-}"

if [ -z "$SERVICE" ]; then
  docker compose logs -f --tail=200
else
  docker compose logs -f --tail=200 "$SERVICE"
fi

# Example Usage:
# /opt/client-stack/scripts/logs.sh
# /opt/client-stack/scripts/logs.sh immich-server
# /opt/client-stack/scripts/logs.sh cloudflared
# /opt/client-stack/scripts/logs.sh caddy