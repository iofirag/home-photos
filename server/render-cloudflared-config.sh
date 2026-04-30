#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Load environment variables
set -a
source .env
set +a

# Render template to config.yaml
envsubst < ./cloudflared/config.yaml.template > ./cloudflared/config.yaml

echo "Generated ./cloudflared/config.yaml"
echo "---"
cat ./cloudflared/config.yaml