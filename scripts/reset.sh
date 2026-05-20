#!/bin/sh

set -e

CLIENT_APP_DIR="/client-app"

log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Deleting client app directory: $CLIENT_APP_DIR"
sudo rm -rf "$CLIENT_APP_DIR"

if ! command -v docker >/dev/null 2>&1; then
	log "Docker is not installed; skipping Docker cleanup"
	log "Reset completed"
	exit 0
fi

if docker info >/dev/null 2>&1; then
	DOCKER_CMD="docker"
elif sudo docker info >/dev/null 2>&1; then
	DOCKER_CMD="sudo docker"
else
	log "Docker is installed but not accessible; skipping Docker cleanup"
	log "Reset completed"
	exit 0
fi

RUNNING_CONTAINERS=$($DOCKER_CMD ps -q)
if [ -n "$RUNNING_CONTAINERS" ]; then
	log "Stopping running Docker containers..."
	$DOCKER_CMD stop $RUNNING_CONTAINERS
else
	log "No running Docker containers found"
fi

ALL_CONTAINERS=$($DOCKER_CMD ps -aq)
if [ -n "$ALL_CONTAINERS" ]; then
	log "Deleting Docker containers..."
	$DOCKER_CMD rm -f $ALL_CONTAINERS
else
	log "No Docker containers found"
fi

ALL_IMAGES=$($DOCKER_CMD images -aq)
if [ -n "$ALL_IMAGES" ]; then
	log "Deleting Docker images..."
	$DOCKER_CMD rmi -f $ALL_IMAGES
else
	log "No Docker images found"
fi

log "Reset completed"
