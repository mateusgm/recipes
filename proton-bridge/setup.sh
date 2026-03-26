#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Proton Bridge IMAP proxy setup"
echo "    Recipe dir: $SCRIPT_DIR"

# ── 1. Build the image ──────────────────────────────────────────

echo ""
echo "==> Building protonmail-bridge image..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" build protonmail-bridge

# ── 2. Initialize bridge and log in (interactive) ──────────────

echo ""
echo "==> Initializing bridge (interactive login)..."
echo "    This will open the bridge CLI."
echo "    At the >>> prompt, run:"
echo "      login     (authenticate with your Proton account)"
echo "      info      (note the bridge-generated credentials)"
echo "      exit      (quit the CLI)"
echo ""

docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm protonmail-bridge init

# ── 3. Start the stack ──────────────────────────────────────────

echo ""
echo "==> Starting proton-bridge stack..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d

# shellcheck disable=SC1091
source "$SCRIPT_DIR/.env"

echo ""
echo "========================================="
echo "  Setup complete!"
echo "========================================="
echo ""
echo "  Email client configuration:"
echo "    - Server:   <your-vpn-ip>"
echo "    - IMAP port: ${IMAP_PORT} (STARTTLS)"
echo "    - SMTP port: ${SMTP_PORT} (STARTTLS)"
echo "    - Username:  (from 'info' command above)"
echo "    - Password:  (from 'info' command above)"
echo ""
echo "  Your email client will warn about the bridge's self-signed"
echo "  certificate. Accept/trust it to proceed."
echo ""
