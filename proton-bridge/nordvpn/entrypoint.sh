#!/usr/bin/env bash
set -euo pipefail

rm -f /run/nordvpn/nordvpnd.pid /run/nordvpn/nordvpnd.sock

mkdir -p /run/dbus
rm -f /run/dbus/pid
dbus-uuidgen > /var/lib/dbus/machine-id 2>/dev/null || true
dbus-daemon --system --nofork &>/dev/null &
sleep 2

nordvpnd &>/dev/null &
disown

for i in $(seq 1 30); do
    if nordvpn status 2>&1 | grep -qi "disconnected\|connected\|status"; then
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "ERROR: nordvpnd failed to start"
        exit 1
    fi
    sleep 1
done

nordvpn set analytics off &>/dev/null || true

login_output=$(nordvpn login --token "${NORDVPN_TOKEN}" 2>&1) || {
    if echo "$login_output" | grep -qi "already logged in"; then
        echo "==> Already logged in"
    else
        echo "ERROR: login failed: $login_output"
        exit 1
    fi
}

meshnet_output=$(nordvpn set meshnet on 2>&1) || {
    if echo "$meshnet_output" | grep -qi "already enabled"; then
        echo "==> Meshnet already enabled"
    else
        echo "ERROR: meshnet failed: $meshnet_output"
        exit 1
    fi
}

nordvpn set mesh-peer-incoming-connections allow

echo "==> Meshnet ready"
nordvpn meshnet peer list 2>/dev/null || true

exec tail -f /dev/null
