#!/usr/bin/env bash
set -e

# Load environment variables
cd "$(dirname "$0")/.."
source .env

# Create dns routes
cloudflared tunnel route dns device1 ssh-${DEVICE_ID}.${BASE_DOMAIN}
cloudflared tunnel route dns device1 health-${DEVICE_ID}.${BASE_DOMAIN}
cloudflared tunnel route dns device1 photos-${DEVICE_ID}.${BASE_DOMAIN}