#!/bin/bash

# Install prerequisites: curl, git, and Docker
sudo apt-get update
sudo apt-get install -y \
  curl \
  git \
  iw \
  dnsmasq \
  iproute2 \
  iputils-ping \
  network-manager

# Verify NetworkManager is running
sudo systemctl enable --now NetworkManager

# Install Docker using the official script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Verify directory does not exist before cloning
rm -rf wifi-connect
# Clone the (Fixed) Balena wifi-connect repository
git clone https://github.com/balena-os/wifi-connect.git
cd wifi-connect
git remote add robot-com-projects https://github.com/robot-com-projects/wifi-connect.git
git fetch robot-com-projects
git checkout -b fix/dockerfile robot-com-projects/fix/dockerfile

# Build and deploy the Docker container
echo "Building and deploying the wifi-connect Docker container..."
sudo docker build -t wifi-connect -f Dockerfile.template .

# Check supported WiFi modes (for debugging)
iw list | grep -A 20 "Supported interface modes"

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