#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Home automation setup"
echo "    Recipe dir: $SCRIPT_DIR"

# ── 1. Apply secret templates ──────────────────────────────────────

echo ""
echo "==> Applying secret templates..."
"$REPO_DIR/apply-secrets.sh" "$SCRIPT_DIR"

# ── 2. Create volume directories ───────────────────────────────────

echo ""
echo "==> Creating volume directories..."

mkdir -p "$SCRIPT_DIR/home-assistant"
mkdir -p "$SCRIPT_DIR/mosquitto/"{data,log}
mkdir -p "$SCRIPT_DIR/grafana/data"
mkdir -p "$SCRIPT_DIR/influxdb/data"

sudo chown -R "$(id -u):$(id -g)" \
  "$SCRIPT_DIR/home-assistant" \
  "$SCRIPT_DIR/mosquitto" \
  "$SCRIPT_DIR/grafana" \
  "$SCRIPT_DIR/influxdb"

# ── 3. Start services ──────────────────────────────────────────────

echo ""
echo "==> Starting home automation stack..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d

# ── 4. Install HACS in Home Assistant ──────────────────────────────

echo ""
echo "==> Installing HACS in Home Assistant..."
echo "    Waiting for Home Assistant to start..."
sleep 15
docker exec homeassistant sh -c 'wget -O - https://get.hacs.xyz | bash -'
docker compose -f "$SCRIPT_DIR/docker-compose.yml" restart homeassistant

# ── 5. Interactive steps (last) ────────────────────────────────────

echo ""
echo "========================================="
echo "  Interactive setup steps"
echo "========================================="
echo ""

echo "==> Setting up Mosquitto MQTT password..."
echo "    You will be prompted to create a password for the 'homeassistant' MQTT user."
docker exec -it mosquitto mosquitto_passwd -c /mosquitto/config/passwd homeassistant
docker compose -f "$SCRIPT_DIR/docker-compose.yml" restart mosquitto

echo ""
echo "========================================="
echo "  Setup complete!"
echo "========================================="
echo ""
echo "  Services running:"
echo "    - Home Assistant  (host network, port 8123)"
echo "    - Grafana         (port from .env, default 3000)"
echo "    - InfluxDB        (port from .env, default 8086)"
echo "    - Mosquitto MQTT  (port from .env, default 1883)"
echo ""
echo "  Next steps:"
echo "    - Complete Home Assistant onboarding at http://<host>:8123"
echo "    - Complete InfluxDB setup at http://<host>:8086"
echo "    - Configure Grafana at http://<host>:3000"
