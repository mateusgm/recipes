#!/usr/bin/env bash
set -euo pipefail

echo "==> Starting NordVPN daemon..."
/etc/init.d/nordvpn start
sleep 5

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
