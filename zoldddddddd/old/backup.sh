#!/usr/bin/env bash
set -e

cd /opt/client-stack

BACKUP_DIR="/opt/client-stack/backups"
DATE="$(date +%Y-%m-%d_%H-%M-%S)"

mkdir -p "$BACKUP_DIR/$DATE"

echo "Creating database backup..."
docker exec immich_postgres pg_dumpall -U postgres > "$BACKUP_DIR/$DATE/database.sql"

echo "Copying config files..."
cp .env "$BACKUP_DIR/$DATE/.env"
cp docker-compose.yaml "$BACKUP_DIR/$DATE/docker-compose.yaml"
cp -r caddy "$BACKUP_DIR/$DATE/caddy"
cp -r immichframe "$BACKUP_DIR/$DATE/immichframe"

echo "Backup created:"
echo "$BACKUP_DIR/$DATE"