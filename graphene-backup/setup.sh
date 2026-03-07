#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> GrapheneOS backup setup"
echo "    Recipe dir: $SCRIPT_DIR"

# ── 1. Collect secrets interactively ───────────────────────────────

echo ""
echo "==> Collecting secrets..."
"$REPO_DIR/collect-secrets.sh" "$SCRIPT_DIR/secrets.env.example"

# ── 2. Obscure Proton Drive password for rclone ───────────────────

echo ""
echo "==> Obscuring Proton Drive password for rclone..."

# Read the plaintext password from secrets.env
PROTON_PASSWORD="$(grep '^PROTON_PASSWORD=' "$SCRIPT_DIR/secrets.env" | cut -d= -f2-)"

if [ -z "$PROTON_PASSWORD" ]; then
  echo "Error: PROTON_PASSWORD is empty in secrets.env"
  exit 1
fi

OBSCURED="$(docker run --rm rclone/rclone:latest obscure "$PROTON_PASSWORD")"

# Append the obscured password to secrets.env for template processing
if grep -q '^PROTON_PASSWORD_OBSCURED=' "$SCRIPT_DIR/secrets.env" 2>/dev/null; then
  sed -i "s|^PROTON_PASSWORD_OBSCURED=.*|PROTON_PASSWORD_OBSCURED=$OBSCURED|" "$SCRIPT_DIR/secrets.env"
else
  echo "PROTON_PASSWORD_OBSCURED=$OBSCURED" >> "$SCRIPT_DIR/secrets.env"
fi

echo "    Done."

# ── 3. Apply secret templates ─────────────────────────────────────

echo ""
echo "==> Applying secret templates..."
"$REPO_DIR/apply-secrets.sh" "$SCRIPT_DIR"

# ── 4. Create volume directories ──────────────────────────────────

echo ""
echo "==> Creating volume directories..."
mkdir -p "$SCRIPT_DIR/data/backups"

# ── 5. Bootstrap step-ca (private ACME certificate authority) ─────

echo ""
echo "==> Bootstrapping step-ca..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d step-ca

echo "    Waiting for step-ca to become healthy..."
timeout=60
while [ $timeout -gt 0 ]; do
  if docker inspect --format='{{.State.Health.Status}}' step-ca 2>/dev/null | grep -q healthy; then
    break
  fi
  sleep 2
  timeout=$((timeout - 2))
done

if [ $timeout -le 0 ]; then
  echo "Error: step-ca did not become healthy within 60 seconds"
  docker logs step-ca
  exit 1
fi

echo "    step-ca is healthy."

# ── 6. Extract root CA certificate ────────────────────────────────

echo ""
echo "==> Extracting root CA certificate..."
docker cp step-ca:/home/step/certs/root_ca.crt "$SCRIPT_DIR/root_ca.crt"
echo "    Saved to $SCRIPT_DIR/root_ca.crt"

# ── 7. Start services ─────────────────────────────────────────────

echo ""
echo "==> Starting graphene-backup stack..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d

# ── 8. Summary ─────────────────────────────────────────────────────

# shellcheck disable=SC1091
source "$SCRIPT_DIR/.env"

echo ""
echo "========================================="
echo "  Setup complete!"
echo "========================================="
echo ""
echo "  Services running:"
echo "    - step-ca       (private ACME CA, internal)"
echo "    - Caddy reverse proxy (HTTPS, port ${HTTPS_PORT:-8443})"
echo "    - rclone WebDAV  (internal, behind Caddy)"
echo "    - rclone sync    (cron: ${SYNC_SCHEDULE:-0 */6 * * *})"
echo ""
echo "  GrapheneOS SeedVault configuration:"
echo "    - Server URL: https://${ACME_HOSTNAME:-<hostname>}:${HTTPS_PORT:-8443}"
echo "    - Username:   (from .env WEBDAV_USER)"
echo "    - Password:   (from .env WEBDAV_PASS)"
echo ""
echo "  IMPORTANT: Install the CA certificate on your phone!"
echo "    1. Transfer root_ca.crt to your GrapheneOS device:"
echo "       $SCRIPT_DIR/root_ca.crt"
echo "    2. On the device, go to:"
echo "       Settings > Security > Encryption & credentials"
echo "       > Install a certificate > CA certificate"
echo "    3. Select the root_ca.crt file and confirm"
echo ""
echo "  Backups are stored locally at:"
echo "    $SCRIPT_DIR/data/backups"
echo ""
echo "  Backups sync to Proton Drive at:"
echo "    protondrive:${PROTON_REMOTE_PATH:-graphene-backups}"
echo ""
echo "  To trigger a manual sync:"
echo "    docker exec rclone-sync rclone sync /data/backups protondrive:${PROTON_REMOTE_PATH:-graphene-backups} --config /config/rclone/rclone.conf -v"
