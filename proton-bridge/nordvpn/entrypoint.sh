#!/usr/bin/env bash
set -euo pipefail

rm -f /run/nordvpn/nordvpnd.pid /run/nordvpn/nordvpnd.sock

mkdir -p /run/dbus
rm -f /run/dbus/pid
dbus-uuidgen > /var/lib/dbus/machine-id 2>/dev/null || true
dbus-daemon --system --nofork &
sleep 2

nordvpnd &
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
nordvpn login --token "${NORDVPN_TOKEN}"
nordvpn set meshnet on
nordvpn meshnet peer incoming allow

echo "==> Meshnet ready"
nordvpn meshnet peer list 2>/dev/null || true

exec tail -f /dev/null
