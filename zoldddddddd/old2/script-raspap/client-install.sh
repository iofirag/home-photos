#!/usr/bin/env bash
set -e

echo "=== Updating system ==="
sudo apt-get update -y

echo "=== Installing dependencies (git, curl) ==="
sudo apt-get install -y git curl ca-certificates

echo "=== Installing Docker (official convenience script) ==="
curl -fsSL https://get.docker.com | sudo sh

echo "=== Enabling Docker service ==="
sudo systemctl enable docker
sudo systemctl start docker

echo "=== Adding current user to docker group ==="
sudo usermod -aG docker $USER || true

echo "NOTE: You may need to log out and log back in for docker group changes."

# echo "=== Cloning balena wifi-connect ==="

# if [ -d "wifi-connect" ]; then
#   echo "Directory wifi-connect already exists. Removing..."
#   rm -rf wifi-connect
# fi

# git clone https://github.com/balena-io/wifi-connect.git

# cd wifi-connect

# echo "=== Preparing Dockerfile ==="

# if [ -f Dockerfile.template ]; then
#   mv Dockerfile.template Dockerfile
#   echo "Renamed Dockerfile.template → Dockerfile"
# else
#   echo "Dockerfile.template not found!"
#   exit 1
# fi

# echo "=== Building Docker image ==="

# sudo docker build -t wifi-connect .

# echo "=== DONE ==="
# echo "Image built: wifi-connect"