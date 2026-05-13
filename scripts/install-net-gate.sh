#!/bin/bash

set -e

echo "=== NET-GATE FULL INSTALL (AUTO HOTSPOT CONFIG) ==="

# -------------------------
# 1. System update
# -------------------------
sudo apt update && sudo apt upgrade -y

# -------------------------
# 2. Dependencies
# -------------------------
sudo apt install -y \
    git curl hostapd dnsmasq \
    network-manager iw rfkill \
    dnsutils iproute2 net-tools \
    python3

# -------------------------
# 3. Install RaspAP
# -------------------------
curl -sL https://install.raspap.com | sudo bash -s -- \
  --yes \
  --openvpn 0 \
  --wireguard 0 \
  --adblock 0 \
  --restapi 0 \
  --dashboard 1

# -------------------------
# 4. Unblock WiFi
# -------------------------
sudo rfkill unblock wifi || true

# -------------------------
# 5. STOP RaspAP services temporarily for config
# -------------------------
sudo systemctl stop hostapd || true
sudo systemctl stop dnsmasq || true

# -------------------------
# 6. HOTSPOT CONFIG (FULL DECLARATION)
# -------------------------

echo "[CONFIG] Writing hostapd config..."

sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=wlan0
driver=nl80211

ssid=NET-GATE-SETUP
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1

auth_algs=1
wpa=2
wpa_passphrase=12345678
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

echo "[CONFIG] Writing dnsmasq config..."

sudo tee /etc/dnsmasq.d/090_netgate.conf > /dev/null <<EOF
interface=wlan0

dhcp-range=10.3.141.50,10.3.141.200,255.255.255.0,24h
dhcp-option=3,10.3.141.1
dhcp-option=6,10.3.141.1

address=/#/10.3.141.1

# Captive portal hijack (IMPORTANT)
address=/connectivitycheck.gstatic.com/10.3.141.1
address=/captive.apple.com/10.3.141.1
address=/msftconnecttest.com/10.3.141.1
address=/www.msftconnecttest.com/10.3.141.1
EOF

# -------------------------
# 7. Set static IP for AP
# -------------------------
sudo ip addr flush dev wlan0 || true
sudo ip addr add 10.3.141.1/24 dev wlan0 || true

# -------------------------
# 8. Enable services
# -------------------------
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

sudo systemctl restart dnsmasq
sudo systemctl restart hostapd

# -------------------------
# 9. NET-GATE config storage
# -------------------------
sudo mkdir -p /etc/net-gate

cat <<EOF | sudo tee /etc/net-gate/config.env
CHECK_INTERVAL=5
FAIL_THRESHOLD=3
HOTSPOT_SSID=NET-GATE-SETUP
EOF

# -------------------------
# 10. Install net-gate script
# -------------------------
sudo tee /usr/local/bin/net-gate.sh > /dev/null <<'EOF'
#!/bin/bash

source /etc/net-gate/config.env

FAIL_COUNT=0
HOTSPOT_ON=0

log() {
    echo "[NET-GATE] $1"
}

is_internet() {
    if curl -s --head --max-time 3 https://google.com | grep -q "200"; then
        return 0
    fi

    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

start_hotspot() {
    log "Starting hotspot (NET-GATE)..."

    sudo nmcli radio wifi off
    sleep 2
    sudo nmcli radio wifi on

    sudo systemctl restart hostapd
    sudo systemctl restart dnsmasq
}

stop_hotspot() {
    log "Stopping hotspot..."

    sudo systemctl stop hostapd
    sudo systemctl stop dnsmasq
}

start_claim() {
    log "Internet available → starting claim process"

    if ! pgrep -f "claim.py" >/dev/null; then
        nohup python3 /home/pi/claim.py >/tmp/claim.log 2>&1 &
    fi
}

while true; do

    if is_internet; then
        FAIL_COUNT=0

        if [ "$HOTSPOT_ON" -eq 1 ]; then
            stop_hotspot
            HOTSPOT_ON=0
        fi

        start_claim

    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        log "no internet detected (fail=$FAIL_COUNT)"

        if [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ]; then
            if [ "$HOTSPOT_ON" -eq 0 ]; then
                start_hotspot
                HOTSPOT_ON=1
                log "hotspot active → SSID: NET-GATE-SETUP"
            fi
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
EOF

sudo chmod +x /usr/local/bin/net-gate.sh

# -------------------------
# 11. DONE
# -------------------------
echo ""
echo "=== INSTALL COMPLETE ==="
echo ""
echo "Hotspot SSID: NET-GATE-SETUP"
echo "Password: 12345678"
echo "Portal: http://10.3.141.1"
echo ""
echo "Run:"
echo "  sudo /usr/local/bin/net-gate.sh"