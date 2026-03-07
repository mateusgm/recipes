#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Media server setup"
echo "    Recipe dir: $SCRIPT_DIR"

# ── 1. Create volume directories ───────────────────────────────────

echo ""
echo "==> Creating volume directories..."

mkdir -p "$SCRIPT_DIR/apps/"{jellyfin/{config,cache},jellyseerr/config,qbittorrent/config,jackett/config,radarr/config,sonarr}
mkdir -p "$SCRIPT_DIR/media"

sudo chown -R "$(id -u):$(id -g)" "$SCRIPT_DIR/apps" "$SCRIPT_DIR/media"

# ── 2. Start services ──────────────────────────────────────────────

echo ""
echo "==> Starting media server stack..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d

echo ""
echo "========================================="
echo "  Setup complete!"
echo "========================================="
echo ""
echo "  Services running:"
echo "    - Jellyfin        (port from .env, default 8096)"
echo "    - Jellyseerr      (port from .env, default 5055)"
echo "    - qBittorrent     (port from .env, default 8080)"
echo "    - Jackett         (port from .env, default 9117)"
echo "    - Radarr          (port from .env, default 7878)"
echo "    - Sonarr          (port from .env, default 8989)"
echo ""
echo "  Next steps:"
echo "    - Set up Jellyfin at http://<host>:8096"
echo "    - Configure Radarr/Sonarr/Jackett for media automation"
