#!/bin/bash

CHECK_INTERVAL=5
FAIL_THRESHOLD=3

FAIL_COUNT=0
HOTSPOT_ON=0

log() {
    echo "[NET-GATE] $1"
}

is_internet() {
    # Strong real internet check
    if curl -s --max-time 3 --head https://google.com | grep -q "200"; then
        return 0
    fi

    # fallback
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

start_hotspot() {
    log "Starting hotspot..."

    # Ensure WiFi is not in client mode
    nmcli radio wifi on

    # Stop client connections safely
    nmcli networking off
    sleep 2
    nmcli networking on

    # Start RaspAP services (safe restart instead of start)
    sudo systemctl restart hostapd
    sudo systemctl restart dnsmasq

    HOTSPOT_ON=1
}

stop_hotspot() {
    log "Stopping hotspot..."

    sudo systemctl stop hostapd
    sudo systemctl stop dnsmasq

    HOTSPOT_ON=0
}

start_claim_process() {
    if ! pgrep -f "claim.py" >/dev/null; then
        log "Starting claim process..."
        nohup python3 /home/pi/claim.py >/tmp/claim.log 2>&1 &
    fi
}

log "Net-Gate started"

while true; do

    if is_internet; then
        FAIL_COUNT=0

        if [ "$HOTSPOT_ON" -eq 1 ]; then
            stop_hotspot
        fi

        start_claim_process

    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        log "No internet (fail=$FAIL_COUNT)"

        if [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ]; then
            if [ "$HOTSPOT_ON" -eq 0 ]; then
                start_hotspot
            fi
        fi
    fi

    sleep "$CHECK_INTERVAL"
done

# sudo nano /usr/local/bin/net-gate.sh
# sudo /usr/local/bin/net-gate.sh