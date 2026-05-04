#!/usr/bin/env bash
set -e

cd /opt/client-stack

docker compose pull
docker compose up -d
docker image prune -f

docker compose ps