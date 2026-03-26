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

# ── 2. Build the image ──────────────────────────────────────────

echo ""
echo "==> Building protonmail-bridge image..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" build protonmail-bridge

# ── 3. Initialize bridge and log in (interactive) ──────────────

echo ""
echo "==> Initializing bridge (interactive login)..."
echo "    This will open the bridge CLI."
echo "    At the >>> prompt, run:"
echo "      login     (authenticate with your Proton account)"
echo "      info      (note the bridge-generated credentials)"
echo "      exit      (quit the CLI)"
echo ""

docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm protonmail-bridge init

# ── 4. Start the full stack ─────────────────────────────────────

echo ""
echo "==> Starting full stack..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d
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
