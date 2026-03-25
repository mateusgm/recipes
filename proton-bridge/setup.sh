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
echo "  Run the following to open the bridge CLI:"
echo ""
echo "    docker exec -it protonmail-bridge /bin/bash"
echo ""
echo "  Inside the container, run:"
echo ""
echo "    login"
echo ""
echo "  Follow the prompts to log in with your Proton account."
echo "  After login, run:"
echo ""
echo "    info"
echo ""
echo "  to see the IMAP/SMTP credentials (bridge-generated password)."
echo "  Save these — you'll need them for your email client."
echo "  Then type 'exit' to leave the container."
echo ""
echo "  Once logged in, start the full stack:"
echo ""
echo "    docker compose -f $SCRIPT_DIR/docker-compose.yml up -d"
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
