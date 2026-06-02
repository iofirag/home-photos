#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_APP_DIR="${CLIENT_APP_DIR:-/client-app}"
USB_MOUNT_ROOT="${USB_MOUNT_ROOT:-/mnt/usb}"
USB_DEVICE="${USB_DEVICE:-}"
USB_MOUNT_DIR="${USB_MOUNT_DIR:-}"
ONBOARDING_BIN="/usr/local/bin/home-photos-onboarding.sh"
HARD_RESET_BIN="/usr/local/bin/home-photos-hard-reset.sh"
ONBOARDING_SERVICE="/etc/systemd/system/home-photos-onboarding.service"
ONBOARDING_ENV="/etc/default/home-photos-onboarding"
JOURNALD_CONFIG="/etc/systemd/journald.conf.d/home-photos-volatile.conf"
ONBOARDING_SERVICE_NAME="home-photos-onboarding.service"

log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

first_removable_partition() {
	local device type removable transport fs_type

	while read -r device type removable transport fs_type; do
		if [ "$type" != "part" ]; then
			continue
		fi

		if [ "$removable" = "1" ] || [ "$transport" = "usb" ]; then
			printf '%s\n' "$device"
			return 0
		fi
	done < <(lsblk -nrpo NAME,TYPE,RM,TRAN,FSTYPE)

	return 1
}

detect_usb_mount_dir() {
	local selected_device mounted_at

	if [ -n "$USB_MOUNT_DIR" ]; then
		printf '%s\n' "$USB_MOUNT_DIR"
		return 0
	fi

	selected_device="$USB_DEVICE"
	if [ -z "$selected_device" ] && command -v lsblk >/dev/null 2>&1; then
		selected_device="$(first_removable_partition || true)"
	fi

	if [ -z "$selected_device" ]; then
		return 1
	fi

	mounted_at="$(findmnt -nr -o TARGET --source "$selected_device" | head -n 1 || true)"
	if [ -z "$mounted_at" ]; then
		return 1
	fi

	printf '%s\n' "$mounted_at"
}

clear_pendrive() {
	local mount_dir

	if ! command -v findmnt >/dev/null 2>&1; then
		log "findmnt is unavailable; skipping pendrive cleanup"
		return 0
	fi

	if ! command -v readlink >/dev/null 2>&1; then
		log "readlink is unavailable; skipping pendrive cleanup"
		return 0
	fi

	if ! command -v find >/dev/null 2>&1; then
		log "find is unavailable; skipping pendrive cleanup"
		return 0
	fi

	mount_dir="$(detect_usb_mount_dir || true)"
	if [ -z "$mount_dir" ]; then
		log "No mounted pendrive found; skipping pendrive cleanup"
		return 0
	fi

	if [ ! -d "$mount_dir" ]; then
		log "Detected pendrive mount is not a directory; skipping: $mount_dir"
		return 0
	fi

	case "$(readlink -f "$mount_dir")" in
		"$(readlink -f "$USB_MOUNT_ROOT")"/*)
			log "Clearing mounted pendrive: $mount_dir"
			sudo find "$mount_dir" -mindepth 1 -xdev -exec rm -rf -- {} +
			;;
		*)
			log "Detected pendrive mount is outside USB_MOUNT_ROOT; skipping: $mount_dir"
			;;
	esac
}

remove_installed_services() {
	log "Removing installed services and reset artifacts..."

	if command -v systemctl >/dev/null 2>&1; then
		sudo systemctl stop "$ONBOARDING_SERVICE_NAME" 2>/dev/null || true
		sudo systemctl disable "$ONBOARDING_SERVICE_NAME" 2>/dev/null || true
	else
		log "systemctl is unavailable; skipping service stop/disable"
	fi

	sudo rm -f "$ONBOARDING_SERVICE" "$ONBOARDING_ENV" "$ONBOARDING_BIN" "$HARD_RESET_BIN" "$JOURNALD_CONFIG"

	if command -v systemctl >/dev/null 2>&1; then
		sudo systemctl daemon-reload 2>/dev/null || true
		sudo systemctl reset-failed "$ONBOARDING_SERVICE_NAME" 2>/dev/null || true
		if systemctl list-unit-files systemd-journald.service >/dev/null 2>&1; then
			sudo systemctl restart systemd-journald 2>/dev/null || true
		fi
	fi
}

remove_installed_services
clear_pendrive

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

ALL_VOLUMES=$($DOCKER_CMD volume ls -q)
if [ -n "$ALL_VOLUMES" ]; then
	log "Deleting Docker volumes..."
	$DOCKER_CMD volume rm -f $ALL_VOLUMES
else
	log "No Docker volumes found"
fi

ALL_IMAGES=$($DOCKER_CMD images -aq)
if [ -n "$ALL_IMAGES" ]; then
	log "Deleting Docker images..."
	$DOCKER_CMD rmi -f $ALL_IMAGES
else
	log "No Docker images found"
fi

log "Reset completed"
