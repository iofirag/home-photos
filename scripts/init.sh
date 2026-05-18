#!/bin/bash

# Install prerequisites: curl, git, and Docker
sudo apt-get update


sudo apt-get install -y \
  network-manager \
  dnsmasq \
  iw \
  iproute2 \
  iputils-ping \
  curl \
  git

# reconfigure NetworkManager enable & running
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
# Verify NetworkManager is running
systemctl status NetworkManager
# Check wifi device is managed
nmcli device status # stuck the install

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

# # copyt provistion.sh to /usr/local/bin and make it executable
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