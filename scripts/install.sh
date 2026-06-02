#!/usr/bin/env bash

# This script initializes the environment for running the wifi-connect Docker container.
# It installs necessary dependencies, sets up NetworkManager, and builds the Docker image.

set -Eeuo pipefail

ONBOARDING_URL="${ONBOARDING_URL:-https://raw.githubusercontent.com/iofirag/home-photos/main/scripts/onboarding.sh}"
HARD_RESET_URL="${HARD_RESET_URL:-https://raw.githubusercontent.com/iofirag/home-photos/main/scripts/hard-reset.sh}"
ONBOARDING_BIN="/usr/local/bin/home-photos-onboarding.sh"
HARD_RESET_BIN="/usr/local/bin/home-photos-hard-reset.sh"
ONBOARDING_SERVICE="/etc/systemd/system/home-photos-onboarding.service"
ONBOARDING_ENV="/etc/default/home-photos-onboarding"
DOCKER_DAEMON_CONFIG="/etc/docker/daemon.json"
JOURNALD_CONFIG="/etc/systemd/journald.conf.d/home-photos-volatile.conf"
WIFI_CONNECT_REPO="${WIFI_CONNECT_REPO:-https://github.com/robot-com-projects/wifi-connect.git}"
WIFI_CONNECT_BRANCH="${WIFI_CONNECT_BRANCH:-fix/dockerfile}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: curl -fsSL <install-url> | sudo bash" >&2
  exit 1
fi

RUN_USER="${SUDO_USER:-${USER:-pi}}"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}

configure_docker_logging() {
  local docker_config_tmp

  echo "Configuring Docker logs to use volatile journald storage..."
  mkdir -p /etc/docker /etc/systemd/journald.conf.d

  tee "$JOURNALD_CONFIG" >/dev/null <<EOF
[Journal]
Storage=volatile
RuntimeMaxUse=256M
RuntimeMaxFileSize=32M
MaxRetentionSec=1day
EOF

  docker_config_tmp="$(mktemp)"
  if [ -f "$DOCKER_DAEMON_CONFIG" ]; then
    cp "$DOCKER_DAEMON_CONFIG" "$DOCKER_DAEMON_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
    jq '. + {
      "log-driver": "journald"
    } + {
      "log-opts": ((."log-opts" // {}) + {
        "tag": "{{.Name}}/{{.ID}}"
      })
    }' "$DOCKER_DAEMON_CONFIG" > "$docker_config_tmp"
  else
    tee "$docker_config_tmp" >/dev/null <<EOF
{
  "log-driver": "journald",
  "log-opts": {
    "tag": "{{.Name}}/{{.ID}}"
  }
}
EOF
  fi

  install -m 0644 "$docker_config_tmp" "$DOCKER_DAEMON_CONFIG"
  rm -f "$docker_config_tmp"

  systemctl restart systemd-journald
  systemctl restart docker
}

trap cleanup EXIT

# Update package lists
apt-get update

# Install prerequisites: curl, git, and Docker
apt-get install -y \
  network-manager \
  dnsmasq \
  iw \
  iproute2 \
  iputils-ping \
  util-linux \
  ca-certificates \
  curl \
  git \
  jq \
  tar

# Reconfigure NetworkManager enable & running
systemctl enable NetworkManager
systemctl start NetworkManager
# Configure dnsmasq to not interfere with NetworkManager
systemctl stop dnsmasq || true
systemctl disable dnsmasq || true

# Install Docker using the official script only when it is missing
if command -v docker >/dev/null 2>&1; then
  echo "Docker is already installed: $(docker --version)"
else
  echo "Docker is not installed. Installing Docker..."
  curl -fsSL https://get.docker.com -o "$WORK_DIR/get-docker.sh"
  sh "$WORK_DIR/get-docker.sh"
fi

if docker compose version >/dev/null 2>&1; then
  echo "Docker Compose is available: $(docker compose version)"
else
  echo "Warning: Docker Compose plugin was not detected after Docker installation."
fi

configure_docker_logging

if id "$RUN_USER" >/dev/null 2>&1; then
  usermod -aG docker "$RUN_USER"
fi

# Clone the fixed wifi-connect branch
# If the upstream repo fixes the Dockerfile issue, use this instead:
# git clone https://github.com/balena-os/wifi-connect.git
git clone --branch "$WIFI_CONNECT_BRANCH" --single-branch "$WIFI_CONNECT_REPO" "$WORK_DIR/wifi-connect"
cd "$WORK_DIR/wifi-connect"

# Build and deploy the Docker container
echo "Building and deploying the wifi-connect Docker container..."
docker build -t wifi-connect -f Dockerfile.template .

echo "Installing hard reset script..."
curl -fsSL "$HARD_RESET_URL" -o "$HARD_RESET_BIN.tmp"
chmod +x "$HARD_RESET_BIN.tmp"
mv "$HARD_RESET_BIN.tmp" "$HARD_RESET_BIN"

echo "Installing onboarding service..."
curl -fsSL "$ONBOARDING_URL" -o "$ONBOARDING_BIN.tmp"
chmod +x "$ONBOARDING_BIN.tmp"
mv "$ONBOARDING_BIN.tmp" "$ONBOARDING_BIN"

tee "$ONBOARDING_ENV" >/dev/null <<EOF
# Optional overrides for Home Photos onboarding.
# SERVER_URL="https://example.com"
# USB_MOUNT_ROOT="/mnt/usb"
# CLIENT_APP_DIR="/mnt/usb/<mounted-usb>/client-app"
EOF

tee "$ONBOARDING_SERVICE" >/dev/null <<EOF
[Unit]
Description=Home Photos onboarding
After=NetworkManager.service docker.service local-fs.target
Wants=docker.service

[Service]
Type=simple
EnvironmentFile=-$ONBOARDING_ENV
ExecStart=$ONBOARDING_BIN
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable home-photos-onboarding.service
systemctl restart home-photos-onboarding.service

# Check supported WiFi modes (for debugging)
echo "Setup completed successfully!"
echo "To remove the app later, run: sudo $HARD_RESET_BIN"
















# iw list | grep -A 20 "Supported interface modes"


# Verify NetworkManager is running
# systemctl status NetworkManager
# Check wifi device is managed
# nmcli device status # stuck the install

# # copy provistion.sh to /usr/local/bin and make it executable
# sudo cp provision.sh /usr/local/bin/provision
# sudo chmod +x /usr/local/bin/provision
# # make it service
# sudo cp provision.service /etc/systemd/system/provision.service
# sudo systemctl enable provision.service
# sudo systemctl start provision.service

# Start the wifi-connect container
# echo "Starting wifi-connect..."
# sudo docker run --rm -it \
#   --name wifi-connect \
#   --network host \
#   --privileged \
#   -v /var/run/dbus:/host/run/dbus \
#   wifi-connect


# sudo docker build -t wifi-connect --build-arg BALENA_ARCH=$BALENA_ARCH -f Dockerfile.template .

# echo "Detected architecture: $BALENA_ARCH"

# Create a Docker Compose file
# echo "Creating a Docker Compose file for wifi-connect..."
# cat <<EOF > docker-compose.yml
# version: "2.1"

# services:
#     wifi-connect:
#         build:
#             context: ./wifi-connect
#             dockerfile: Dockerfile.template
#             args:
#                 BALENA_ARCH: "\${BALENA_ARCH}"
#         network_mode: "host"
#         privileged: true
#         labels:
#             io.balena.features.dbus: '1'
#             io.balena.features.firmware: "1"
#         cap_add:
#             - NET_ADMIN
#         environment:
#             DBUS_SYSTEM_BUS_ADDRESS: "unix:path=/host/run/dbus/system_bus_socket"
# EOF

# Build and deploy the Docker container
# sudo docker compose up