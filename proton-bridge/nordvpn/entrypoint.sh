#!/usr/bin/env bash
set -euo pipefail

echo "==> Starting D-Bus..."
mkdir -p /run/dbus
dbus-daemon --system --nofork &
sleep 1

echo "==> Starting NordVPN daemon..."
nordvpnd &
disown

echo "==> Waiting for daemon..."
for i in $(seq 1 30); do
    if nordvpn account &>/dev/null 2>&1 || nordvpn status 2>&1 | grep -q -v "couldn't reach"; then
        echo "    Daemon ready after ${i}s"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "ERROR: Daemon failed to start after 30s"
        exit 1
    fi
    sleep 1
done

echo "==> Disabling analytics prompts..."
nordvpn set analytics off

echo "==> Logging in..."
nordvpn login --token "${NORDVPN_TOKEN}"

echo "==> Enabling Meshnet..."
nordvpn set meshnet on

# Allow incoming traffic from other mesh peers so they can reach IMAP/SMTP
echo "==> Allowing incoming mesh traffic..."
nordvpn meshnet peer incoming allow

echo "==> Meshnet is up. Mesh address:"
nordvpn meshnet peer list 2>/dev/null || true

echo "==> NordVPN container ready. Keeping alive..."
# Keep the container running
exec tail -f /dev/null
