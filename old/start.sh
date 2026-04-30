#!/usr/bin/env bash
set -e

cd /opt/client-stack

mkdir -p \
  immich/library \
  immich/postgres \
  immich/model-cache \
  immichframe/Config \
  caddy \
  backups

./scripts/render-cloudflared-config.sh
./scripts/create-dns-routes.sh

docker compose up -d
docker compose ps