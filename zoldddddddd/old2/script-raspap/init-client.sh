

sudo rfkill unblock wifi
sudo ip link set wlan0 down
sudo ip link set wlan0 up

sudo systemctl restart hostapd

# https://tricknology.in/turn-your-raspberry-pi-intro-wi-fi-access-point/
(
sudo apt update
# Install RaspAP
sudo apt install iptables -y
sudo apt install -y git curl hostapd dnsmasq
curl -sL https://install.raspap.com | bash
)




sudo apt install -y \
    network-manager \
    dnsmasq \
    curl \
    jq

# Install wifi-connect
# sudo apt install -y network-manager dnsmasq

wget https://github.com/balena-os/wifi-connect/releases/latest/download/wifi-connect-linux-armv7hf
sudo mv wifi-connect-linux-armv7hf /usr/local/bin/wifi-connect
sudo chmod +x /usr/local/bin/wifi-connect

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER 

# check_internet
curl -s --max-time 3 https://clients3.google.com/generate_204 >/dev/null

#!/bin/bash

HOTSPOT_NAME="MyDeviceHotspot"

check_internet() {
    ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1
}

start_hotspot() {
    echo "Starting hotspot..."

    # Check if hotspot already exists
    if ! nmcli connection show "$HOTSPOT_NAME" > /dev/null 2>&1; then
        nmcli connection add type wifi ifname wlan0 con-name "$HOTSPOT_NAME" autoconnect no ssid "$HOTSPOT_NAME"
        nmcli connection modify "$HOTSPOT_NAME" 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
        nmcli connection modify "$HOTSPOT_NAME" wifi-sec.key-mgmt wpa-psk
        nmcli connection modify "$HOTSPOT_NAME" wifi-sec.psk "SecurePassword123"
    fi

    nmcli connection up "$HOTSPOT_NAME"
}

stop_hotspot() {
    echo "Stopping hotspot..."

    if nmcli connection show "$HOTSPOT_NAME" > /dev/null 2>&1; then
        nmcli connection down "$HOTSPOT_NAME" > /dev/null 2>&1
    fi
}

while true; do
    if check_internet; then
        echo "Internet is available. Proceeding with claim process."
        stop_hotspot

        # claim script here
        break
    else
        echo "No internet connection. Starting hotspot."
        start_hotspot
    fi

    sleep 30
done

exit 0