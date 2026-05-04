#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
  echo "Usage: restore.sh /opt/client-stack/backups/YYYY-MM-DD_HH-MM-SS"
  exit 1
fi

BACKUP_PATH="$1"

cd /opt/client-stack

echo "Stopping stack..."
docker compose down

echo "Restoring config files..."
cp "$BACKUP_PATH/.env" .env
cp "$BACKUP_PATH/docker-compose.yaml" docker-compose.yaml
cp -r "$BACKUP_PATH/caddy" caddy
cp -r "$BACKUP_PATH/immichframe" immichframe

echo "Starting database..."
docker compose up -d database redis
sleep 10

echo "Restoring database..."
cat "$BACKUP_PATH/database.sql" | docker exec -i immich_postgres psql -U postgres

echo "Starting all services..."
docker compose up -d

docker compose ps