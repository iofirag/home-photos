#!/bin/bash

set -e

echo "======================================="
echo "NET-GATE + RaspAP INSTALLER"
echo "======================================="

# --------------------------------------------------
# UPDATE SYSTEM
# --------------------------------------------------
sudo apt update
sudo apt upgrade -y

# --------------------------------------------------
# INSTALL REQUIRED PACKAGES
# --------------------------------------------------
sudo apt install -y \
  git
  curl \
  iw \
  rfkill \
  dnsmasq \
  hostapd \
  network-manager \
  net-tools \
  iproute2 \
  python3

# --------------------------------------------------
# INSTALL RASPAP (NO QUESTIONS)
# --------------------------------------------------
curl -sL https://install.raspap.com | sudo bash -s -- \
  --yes \
  --openvpn 0 \
  --wireguard 0 \
  --adblock 0 \
  --restapi 0 \
  --dashboard 1

# --------------------------------------------------
# WIFI UNBLOCK
# --------------------------------------------------
sudo rfkill unblock wifi || true

# --------------------------------------------------
# STOP SERVICES BEFORE CONFIG
# --------------------------------------------------
sudo systemctl stop hostapd || true
sudo systemctl stop dnsmasq || true

# --------------------------------------------------
# HOSTAPD CONFIG
# --------------------------------------------------
sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=wlan0
driver=nl80211

ssid=NET-GATE-SETUP

hw_mode=g
channel=6

ieee80211n=1
wmm_enabled=1

macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0

wpa=2
wpa_passphrase=12345678
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

# --------------------------------------------------
# HOSTAPD DEFAULTS
# --------------------------------------------------
sudo tee /etc/default/hostapd > /dev/null <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

# --------------------------------------------------
# DNSMASQ CONFIG
# --------------------------------------------------
sudo tee /etc/dnsmasq.d/090_netgate.conf > /dev/null <<EOF
interface=wlan0

dhcp-range=10.3.141.50,10.3.141.200,255.255.255.0,24h

dhcp-option=3,10.3.141.1
dhcp-option=6,10.3.141.1

# Redirect ALL DNS requests to portal
address=/#/10.3.141.1

# Captive portal triggers
address=/connectivitycheck.gstatic.com/10.3.141.1
address=/clients3.google.com/10.3.141.1
address=/captive.apple.com/10.3.141.1
address=/msftconnecttest.com/10.3.141.1
address=/www.msftconnecttest.com/10.3.141.1
EOF

# --------------------------------------------------
# CONFIGURE STATIC IP FOR HOTSPOT
# --------------------------------------------------
sudo ip link set wlan0 down || true
sudo ip addr flush dev wlan0 || true
sudo ip addr add 10.3.141.1/24 dev wlan0
sudo ip link set wlan0 up

# --------------------------------------------------
# ENABLE REQUIRED SERVICES
# --------------------------------------------------
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl enable lighttpd

# --------------------------------------------------
# CREATE ONBOARDING PORTAL PAGE
# --------------------------------------------------
sudo mkdir -p /var/www/html

sudo tee /var/www/html/index.php > /dev/null <<'EOF'
<!DOCTYPE html>
<html lang="en">

<head>

<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">

<title>NET-GATE Setup</title>

<style>

body{
    margin:0;
    background:#f4f7fb;
    font-family:Arial,sans-serif;
    display:flex;
    justify-content:center;
    align-items:center;
    height:100vh;
}

.card{
    width:340px;
    background:white;
    padding:30px;
    border-radius:18px;
    box-shadow:0 10px 30px rgba(0,0,0,0.12);
    text-align:center;
}

h1{
    margin-top:0;
    color:#222;
}

p{
    color:#666;
    margin-bottom:20px;
}

input{
    width:100%;
    padding:14px;
    margin-bottom:14px;
    border:1px solid #ddd;
    border-radius:10px;
    box-sizing:border-box;
    font-size:15px;
}

button{
    width:100%;
    padding:14px;
    border:none;
    border-radius:10px;
    background:#2563eb;
    color:white;
    font-size:16px;
    cursor:pointer;
}

button:hover{
    opacity:0.95;
}

.footer{
    margin-top:18px;
    font-size:12px;
    color:#999;
}

</style>

</head>

<body>

<div class="card">

<h1>NET-GATE</h1>

<p>Configure your WiFi connection</p>

<form>

<input
type="text"
placeholder="WiFi Network Name"
/>

<input
type="password"
placeholder="WiFi Password"
/>

<button type="submit">
Connect Device
</button>

</form>

<div class="footer">
Device onboarding portal
</div>

</div>

</body>
</html>
EOF

# --------------------------------------------------
# NET-GATE CONFIG STORAGE
# --------------------------------------------------
sudo mkdir -p /etc/net-gate

sudo tee /etc/net-gate/config.env > /dev/null <<EOF
CHECK_INTERVAL=5
FAIL_THRESHOLD=3
EOF

# --------------------------------------------------
# CLAIM PLACEHOLDER
# --------------------------------------------------
cat <<EOF > /home/pi/claim.py
print("Claim process started")
EOF

# --------------------------------------------------
# NET-GATE SCRIPT
# --------------------------------------------------
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

    return 1
}

start_hotspot() {

    log "starting hotspot"

    sudo ip link set wlan0 down || true
    sudo ip addr flush dev wlan0 || true
    sudo ip addr add 10.3.141.1/24 dev wlan0
    sudo ip link set wlan0 up

    sudo systemctl restart dnsmasq
    sudo systemctl restart hostapd

    HOTSPOT_ON=1
}

stop_hotspot() {

    log "stopping hotspot"

    sudo systemctl stop hostapd
    sudo systemctl stop dnsmasq

    HOTSPOT_ON=0
}

start_claim_process() {

    log "starting claim process"

    if ! pgrep -f "claim.py" >/dev/null; then
        nohup python3 /home/pi/claim.py >/tmp/claim.log 2>&1 &
    fi
}

while true
do

    if is_internet; then

        FAIL_COUNT=0

        if [ "$HOTSPOT_ON" -eq 1 ]; then
            stop_hotspot
        fi

        start_claim_process

    else

        FAIL_COUNT=$((FAIL_COUNT + 1))

        log "no internet detected (fail=$FAIL_COUNT)"

        if [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ]; then

            if [ "$HOTSPOT_ON" -eq 0 ]; then
                start_hotspot
            fi
        fi
    fi

    sleep "$CHECK_INTERVAL"

done
EOF

sudo chmod +x /usr/local/bin/net-gate.sh

# --------------------------------------------------
# RESTART SERVICES
# --------------------------------------------------
sudo systemctl restart lighttpd
sudo systemctl restart dnsmasq
sudo systemctl restart hostapd

echo ""
echo "======================================="
echo "INSTALL COMPLETE"
echo "======================================="
echo ""
echo "SSID: NET-GATE-SETUP"
echo "PASSWORD: 12345678"
echo "PORTAL: http://10.3.141.1"
echo ""
echo "START WITH:"
echo "sudo /usr/local/bin/net-gate.sh"
echo ""