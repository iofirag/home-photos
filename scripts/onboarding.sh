#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  if command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  fi
  echo "This script requires bash. Install bash, then run: bash $0" >&2
  exit 1
fi

set -Eeuo pipefail

WIFI_CONNECT_NAME="wifi-connect"
CHECK_URL="https://clients3.google.com/generate_204"
RESET_NETWORK_DELAY=30
INTERVAL=5
SERVER_URL="${SERVER_URL:-10.0.0.1:5000}" # "aghaiofir.win"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USB_MOUNT_ROOT="${USB_MOUNT_ROOT:-/media/home-photos}"
USB_DEVICE="${USB_DEVICE:-}"
USB_MOUNT_DIR="${USB_MOUNT_DIR:-}"
CLIENT_APP_DIR="${CLIENT_APP_DIR:-}"
PROVISION_MARKER=""
POSTGRES_UID="999"
POSTGRES_GID="999"
LOG_FILE="${ONBOARDING_LOG_FILE:-/var/log/home-photos-onboarding.log}"
USB_WAIT_INTERVAL="${USB_WAIT_INTERVAL:-5}"
SUPPORTED_USB_FILESYSTEMS="${SUPPORTED_USB_FILESYSTEMS:-ext4}"
APP_STARTED=false

init_logging() {
  local log_dir
  log_dir="$(dirname "$LOG_FILE")"

  if ! mkdir -p "$log_dir" 2>/dev/null || ! touch "$LOG_FILE" 2>/dev/null; then
    LOG_FILE="/tmp/home-photos-onboarding.log"
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
  fi

  exec > >(tee -a "$LOG_FILE") 2>&1
}

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

on_error() {
  local exit_code=$?
  log "ERROR: command failed at line $1: $2 (exit $exit_code)"
  log "See log file: $LOG_FILE"
  exit "$exit_code"
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    log "Missing required command: $command_name"
    log "Run install.sh first, then rerun onboarding.sh"
    exit 1
  fi
}

path_is_mounted() {
  local mount_dir="$1"
  findmnt -rn --target "$mount_dir" >/dev/null 2>&1
}

sanitize_mount_name() {
  basename "$1" | tr -c '[:alnum:]_.-' '-'
}

filesystem_is_supported() {
  local fs_type="$1"
  local supported_fs

  for supported_fs in $SUPPORTED_USB_FILESYSTEMS; do
    if [ "$fs_type" = "$supported_fs" ]; then
      return 0
    fi
  done

  return 1
}

server_base_url() {
  case "$SERVER_URL" in
    http://*|https://*)
      printf '%s\n' "${SERVER_URL%/}"
      ;;
    *)
      printf 'http://%s\n' "${SERVER_URL%/}"
      ;;
  esac
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

chown_or_warn() {
  local owner="$1"
  local path="$2"
  local purpose="$3"
  local chown_output
  local fs_type

  if chown_output=$(sudo chown -R "$owner" "$path" 2>&1); then
    return 0
  fi

  fs_type=$(df -T "$path" 2>/dev/null | awk 'NR == 2 {print $2}' || true)
  log "Warning: could not change ownership for $purpose: $path -> $owner${fs_type:+ (filesystem: $fs_type)}"
  if [ -n "$chown_output" ]; then
    log "chown output: $chown_output"
  fi
  log "USB filesystems like FAT, exFAT, and NTFS may not support Linux ownership. Use ext4 for Docker/Postgres data if containers fail to start."
}

verify_client_storage_ready() {
  local available_kb available_mb test_file

  sudo mkdir -p "$CLIENT_APP_DIR"

  available_kb="$(df -Pk "$USB_MOUNT_DIR" | awk 'NR == 2 {print $4}')"
  available_mb=$((available_kb / 1024))

  test_file="$CLIENT_APP_DIR/.write-test"
  if ! sudo sh -c 'printf test > "$1"' sh "$test_file"; then
    log "USB pendrive is mounted but not writable: $USB_MOUNT_DIR"
    return 1
  fi
  sudo rm -f "$test_file"

  log "USB storage passed validation: ext4-compatible, writable, ${available_mb}MB free"
}

ensure_client_storage_mounted() {
  local fs_type mount_name mounted_at selected_device

  while true; do
    selected_device="${USB_DEVICE:-}"

    if [ -z "$selected_device" ]; then
      selected_device="$(first_removable_partition || true)"
    fi

    if [ -z "$selected_device" ]; then
      log "Waiting for USB pendrive..."
      sleep "$USB_WAIT_INTERVAL"
      continue
    fi

    if [ ! -b "$selected_device" ]; then
      log "Configured USB device is not a block device: $selected_device"
      sleep "$USB_WAIT_INTERVAL"
      continue
    fi

    fs_type="$(lsblk -nrpo FSTYPE "$selected_device" | head -n 1)"
    if [ -z "$fs_type" ]; then
      log "USB device has no filesystem: $selected_device"
      log "Format the pendrive as ext4 before handing it to a client."
      sleep "$USB_WAIT_INTERVAL"
      continue
    fi

    if ! filesystem_is_supported "$fs_type"; then
      log "Unsupported USB filesystem '$fs_type' on $selected_device"
      log "Use one of: $SUPPORTED_USB_FILESYSTEMS"
      sleep "$USB_WAIT_INTERVAL"
      continue
    fi

    mounted_at="$(findmnt -nr -o TARGET --source "$selected_device" | head -n 1 || true)"
    if [ -n "$mounted_at" ]; then
      if [ -n "$USB_MOUNT_DIR" ] && [ "$USB_MOUNT_DIR" != "$mounted_at" ]; then
        log "USB device is already mounted at $mounted_at; using that path instead of $USB_MOUNT_DIR"
      fi
      USB_MOUNT_DIR="$mounted_at"
    else
      mount_name="$(sanitize_mount_name "$selected_device")"
      USB_MOUNT_DIR="${USB_MOUNT_DIR:-$USB_MOUNT_ROOT/$mount_name}"
      sudo mkdir -p "$USB_MOUNT_DIR"
      log "Mounting USB pendrive $selected_device at $USB_MOUNT_DIR"
      sudo mount "$selected_device" "$USB_MOUNT_DIR"
    fi

    if ! path_is_mounted "$USB_MOUNT_DIR"; then
      log "USB mount is not active yet: $USB_MOUNT_DIR"
      sleep "$USB_WAIT_INTERVAL"
      continue
    fi

    CLIENT_APP_DIR="${CLIENT_APP_DIR:-$USB_MOUNT_DIR/client-app}"
    PROVISION_MARKER="$CLIENT_APP_DIR/.provisioned"
    if ! verify_client_storage_ready; then
      sleep "$USB_WAIT_INTERVAL"
      continue
    fi
    log "USB storage ready: $USB_MOUNT_DIR"
    log "Client app directory: $CLIENT_APP_DIR"
    return 0
  done
}

trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

internet_ok() {
  curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$CHECK_URL" | grep -q "204"
}

check_requirements() {
  require_command curl
  require_command docker
  require_command ip
  require_command awk
  require_command findmnt
  require_command lsblk
  require_command mount
  require_command df
}

start_hotspot() {
  if docker ps --format '{{.Names}}' | grep -q "$WIFI_CONNECT_NAME"; then
    log "Hotspot already running"
    return
  fi

  log "Starting WiFi hotspot (wifi-connect)..."
  docker run --rm \
    --name "$WIFI_CONNECT_NAME" \
    --network host \
    --privileged \
    -v /var/run/dbus:/host/run/dbus \
    "$WIFI_CONNECT_NAME" &
}

stop_hotspot() {
  if docker ps --format '{{.Names}}' | grep -q "$WIFI_CONNECT_NAME"; then
    log "Stopping WiFi hotspot..."
    docker stop "$WIFI_CONNECT_NAME" || true
    docker rm "$WIFI_CONNECT_NAME" || true
  else
    log "WiFi hotspot is not running"
  fi
}

# claim_device() {
#   log "Internet available → running claim process"

#   # Replace this with your real onboarding logic
#   curl -X POST "https://your-server.com/device/claim" \
#     -H "Content-Type: application/json" \
#     -d "{\"device_id\": \"$(cat /etc/machine-id 2>/dev/null || hostname)\"}" \
#     || log "Claim request failed"
# }

download_application_files() {
  local archive_path

  archive_path="$(mktemp)"
  log "Downloading application files..."
  curl -fL -o "$archive_path" "$(server_base_url)/download-client-template-files"
  log "Extracting application files..."
  sudo mkdir -p "$CLIENT_APP_DIR"
  sudo tar --no-same-owner --no-same-permissions -xzf "$archive_path" -C "$CLIENT_APP_DIR" --strip-components=1
  chown_or_warn "$(id -u):$(id -g)" "$CLIENT_APP_DIR" "client app files"
  rm -f "$archive_path"
}

create_client_tunnel() {
  # get mac address
  MAC_ADDRESS=$(ip link show | awk '/ether/ {print $2}' | head -n 1)
  DEVICE_ID=$(printf '%s' "$MAC_ADDRESS" | tr ':' '-')
  ENV_EXAMPLE_FILE="$CLIENT_APP_DIR/.env.example"
  ENV_FILE="$CLIENT_APP_DIR/.env"
  RESPONSE_FILE=$(mktemp)

  log "Creating client tunnel with MAC address: $MAC_ADDRESS"
  curl -fsS -X POST "$(server_base_url)/create-client-tunnel" \
    -H "Content-Type: application/json" \
    -d "{\"device_id\": \"$DEVICE_ID\"}" \
    -o "$RESPONSE_FILE" \
    || { rm -f "$RESPONSE_FILE"; log "Create client tunnel request failed"; return 1; }

  if [ ! -f "$ENV_EXAMPLE_FILE" ]; then
    rm -f "$RESPONSE_FILE"
    log "Missing env example file: $ENV_EXAMPLE_FILE"
    return 1
  fi

  cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
  if [ -s "$ENV_FILE" ]; then
    printf '\n' >> "$ENV_FILE"
  fi
  tr -d '{}"' < "$RESPONSE_FILE" \
    | awk -v RS=',' '{
        separator=index($0, ":")
        if (separator == 0) next
        key=substr($0, 1, separator - 1)
        value=substr($0, separator + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        if (key != "") print key "=" value
      }' \
    >> "$ENV_FILE"
  rm -f "$RESPONSE_FILE"
}

prepare_app_data() {
  log "Preparing application data directories..."
  sudo mkdir -p \
    "$CLIENT_APP_DIR/client-data/immich/upload" \
    "$CLIENT_APP_DIR/client-data/immich/postgres" \
    "$CLIENT_APP_DIR/client-data/immichframe/Config"
  chown_or_warn "$POSTGRES_UID:$POSTGRES_GID" "$CLIENT_APP_DIR/client-data/immich/postgres" "Postgres data"
}

prepare_immichframe_manager_build_context() {
  local repo_dir

  if sudo docker image inspect immich_frame_manager:latest >/dev/null 2>&1; then
    log "ImmichFrame Manager image already exists; skipping build context setup"
    return 0
  fi

  require_command git
  repo_dir="$CLIENT_APP_DIR/ImmichFrame-Manager"
  rm -rf "$repo_dir"

  log "Cloning ImmichFrame Manager for Docker Compose build..."
  git clone https://github.com/lbartuzi/ImmichFrame-Manager.git "$repo_dir"
}

ensure_immichframe_manager_image() {
  if sudo docker image inspect immich_frame_manager:latest >/dev/null 2>&1; then
    return 0
  fi

  log "Building ImmichFrame Manager Docker image..."
  sudo docker compose build immichframe-manager
}

start_app() {
  log "Starting application..."
  if [ ! -d "$CLIENT_APP_DIR" ]; then
    log "Client app directory not found: $CLIENT_APP_DIR"
    return 1
  fi
  prepare_app_data
  prepare_immichframe_manager_build_context
  (
    trap 'rm -rf "$CLIENT_APP_DIR/ImmichFrame-Manager"' EXIT
    cd "$CLIENT_APP_DIR"
    ensure_immichframe_manager_image
    sudo docker compose up -d
  )
}

reset_network() {
  log "Resetting wifi network"
  # Add any necessary commands to reset the network here
  sudo systemctl restart NetworkManager || log "Failed to restart NetworkManager"
  nmcli radio wifi on || log "Failed to turn wifi on"
}

main() {
  init_logging
  log "Starting onboarding script"
  log "Log file: $LOG_FILE"
  check_requirements
  ensure_client_storage_mounted

  if ! internet_ok; then
    reset_network
    sleep "$RESET_NETWORK_DELAY"
  fi

  log "Starting provisioning loop..."
  while true; do
    if internet_ok; then
      log "Internet detected"
      stop_hotspot
      # claim_device
      if [ ! -f "$PROVISION_MARKER" ]; then
        download_application_files
        create_client_tunnel
        start_app
        touch "$PROVISION_MARKER"
        APP_STARTED=true
      else
        if [ "$APP_STARTED" = false ]; then
          log "App already provisioned; ensuring application is running"
          start_app
          APP_STARTED=true
        fi
      fi
    else
      log "No internet detected - starting hotspot"
      start_hotspot
    fi

    sleep "$INTERVAL"
  done
}

main "$@"