#!/bin/bash

# This script initializes the environment for running the wifi-connect Docker container.
# It installs necessary dependencies, sets up NetworkManager, and builds the Docker image.

ONBOARDING_URL="https://raw.githubusercontent.com/iofirag/home-photos/main/scripts/onboarding.sh"
ONBOARDING_BIN="/usr/local/bin/home-photos-onboarding.sh"
ONBOARDING_SERVICE="/etc/systemd/system/home-photos-onboarding.service"

# Update package lists
sudo apt-get update

# Install prerequisites: curl, git, and Docker
sudo apt-get install -y \
  network-manager \
  dnsmasq \
  iw \
  iproute2 \
  iputils-ping \
  curl \
  git

# Reconfigure NetworkManager enable & running
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
# Configure dnsmasq to not interfere with NetworkManager
sudo systemctl stop dnsmasq
sudo systemctl disable dnsmasq

# Install Docker using the official script only when it is missing
if command -v docker >/dev/null 2>&1; then
  echo "Docker is already installed: $(docker --version)"
else
  echo "Docker is not installed. Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm -f get-docker.sh
fi

if docker compose version >/dev/null 2>&1; then
  echo "Docker Compose is available: $(docker compose version)"
else
  echo "Warning: Docker Compose plugin was not detected after Docker installation."
fi

sudo usermod -aG docker "$USER"

# Remove any existing wifi-connect directory to avoid duplication
rm -rf wifi-connect
# Clone the fixed wifi-connect branch
# If the upstream repo fixes the Dockerfile issue, use this instead:
# git clone https://github.com/balena-os/wifi-connect.git
git clone --branch fix/dockerfile --single-branch https://github.com/robot-com-projects/wifi-connect.git
cd wifi-connect

# Build and deploy the Docker container
echo "Building and deploying the wifi-connect Docker container..."
sudo docker build -t wifi-connect -f Dockerfile.template .

# Remove the cloned wifi-connect directory after Docker image is built
cd ..
rm -rf wifi-connect

echo "Installing onboarding service..."
sudo curl -fL "$ONBOARDING_URL" -o "$ONBOARDING_BIN"
sudo chmod +x "$ONBOARDING_BIN"

sudo tee "$ONBOARDING_SERVICE" >/dev/null <<EOF
[Unit]
Description=Home Photos onboarding
After=network-online.target NetworkManager.service docker.service
Wants=network-online.target docker.service

[Service]
Type=simple
ExecStart=$ONBOARDING_BIN
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable home-photos-onboarding.service
sudo systemctl start home-photos-onboarding.service

# Check supported WiFi modes (for debugging)
echo "Setup completed successfully!"
















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