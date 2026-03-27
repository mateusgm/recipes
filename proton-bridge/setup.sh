#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Proton Bridge + NordVPN Meshnet setup"
echo "    Recipe dir: $SCRIPT_DIR"

# ── 0. Check for required config ─────────────────────────────────

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "ERROR: .env file not found. Copy .env.example to .env and fill in your NORDVPN_TOKEN."
    exit 1
fi

# shellcheck disable=SC1091
source "$SCRIPT_DIR/.env"

if [ -z "${NORDVPN_TOKEN:-}" ]; then
    echo "ERROR: NORDVPN_TOKEN is not set in .env"
    exit 1
fi

# ── 1. Build images ──────────────────────────────────────────────

echo ""
echo "==> Building images..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" build

# ── 2. Initialize bridge and log in (interactive) ───────────────

echo ""
echo "==> Initializing bridge (interactive login)..."
echo "    This will open the bridge CLI."
echo "    At the >>> prompt, run:"
echo "      login     (authenticate with your Proton account)"
echo "      info      (note the bridge-generated credentials)"
echo "      exit      (quit the CLI)"
echo ""

docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm protonmail-bridge init

# ── 3. Start the stack ───────────────────────────────────────────

echo ""
echo "==> Starting stack..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d

echo ""
echo "==> Waiting for Meshnet to come up..."
sleep 10

echo ""
echo "==> NordVPN Meshnet status:"
docker exec nordvpn-protonbridge nordvpn meshnet peer list 2>/dev/null || echo "    (run 'docker logs nordvpn-protonbridge' to troubleshoot)"

echo ""
echo "========================================="
echo "  Setup complete!"
echo "========================================="
echo ""
echo "  Email client configuration:"
echo "    - Server:   <your-meshnet-hostname>.nord"
echo "    - IMAP port: 143 (STARTTLS)"
echo "    - SMTP port: 25  (STARTTLS)"
echo "    - Username:  (from 'info' command above)"
echo "    - Password:  (from 'info' command above)"
echo ""
echo "  Your email client will warn about the bridge's self-signed"
echo "  certificate. Accept/trust it to proceed."
echo ""
echo "  To check your Meshnet address:"
echo "    docker exec nordvpn-protonbridge nordvpn meshnet peer list"
echo ""
