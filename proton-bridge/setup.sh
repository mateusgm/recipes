#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Proton Bridge IMAP proxy setup"
echo "    Recipe dir: $SCRIPT_DIR"

# ── 1. Generate self-signed TLS certificate ─────────────────────

echo ""
echo "==> Generating self-signed TLS certificate..."
mkdir -p "$SCRIPT_DIR/certs"

if [ -f "$SCRIPT_DIR/certs/cert.pem" ] && [ -f "$SCRIPT_DIR/certs/key.pem" ]; then
  echo "    Certificates already exist, skipping generation."
else
  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout "$SCRIPT_DIR/certs/key.pem" \
    -out "$SCRIPT_DIR/certs/cert.pem" \
    -subj "/CN=proton-bridge" \
    -addext "subjectAltName=DNS:proton-bridge,DNS:localhost"
  echo "    Generated certs/cert.pem and certs/key.pem (valid 10 years)."
fi

# ── 2. Start bridge for initial login ───────────────────────────

echo ""
echo "==> Starting protonmail-bridge for initial login..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d protonmail-bridge

echo "    Waiting for bridge to initialize..."
sleep 5

echo ""
echo "========================================="
echo "  Bridge is running — log in now"
echo "========================================="
echo ""
echo "  1. Exec into the container:"
echo ""
echo "       docker exec -it protonmail-bridge /bin/bash"
echo ""
echo "  2. Kill the background bridge and relaunch in CLI mode:"
echo ""
echo "       pkill bridge"
echo "       /usr/bin/bridge --cli"
echo ""
echo "  3. At the >>> prompt, log in:"
echo ""
echo "       login"
echo ""
echo "     Follow the prompts (username, password, 2FA)."
echo ""
echo "  4. Get your IMAP/SMTP credentials:"
echo ""
echo "       info"
echo ""
echo "     Save the bridge-generated password — you'll need it"
echo "     for your email client."
echo ""
echo "  5. Exit the CLI (Ctrl+C), then exit the container (exit)."
echo ""
echo "  6. Restart the container and start the full stack:"
echo ""
echo "       docker compose -f $SCRIPT_DIR/docker-compose.yml restart protonmail-bridge"
echo "       docker compose -f $SCRIPT_DIR/docker-compose.yml up -d"
echo ""

# shellcheck disable=SC1091
source "$SCRIPT_DIR/.env"

echo "  Email client configuration:"
echo "    - Server:   <your-vpn-ip>"
echo "    - IMAP port: ${IMAPS_PORT} (SSL/TLS)"
echo "    - SMTP port: ${SMTPS_PORT} (SSL/TLS)"
echo "    - Username:  (from 'info' command above)"
echo "    - Password:  (from 'info' command above)"
echo ""
echo "  Note: Your email client will warn about the self-signed"
echo "  certificate on first connection. Accept/trust it to proceed."
echo ""
