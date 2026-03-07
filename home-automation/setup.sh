#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Home automation setup"
echo "    Recipe dir: $SCRIPT_DIR"

# ── 1. System packages ─────────────────────────────────────────────

echo ""
echo "==> Installing system packages..."

sudo apt-get update
sudo apt-get install -y \
  curl \
  git \
  vim \
  tmux \
  zsh \
  gettext-base  # provides envsubst

# Docker (official repo)
if ! command -v docker &>/dev/null; then
  echo "==> Installing Docker..."
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  echo "    Added $USER to docker group. You may need to log out and back in."
fi

# Tailscale
if ! command -v tailscale &>/dev/null; then
  echo "==> Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sudo sh
fi

# GitHub CLI
if ! command -v gh &>/dev/null; then
  echo "==> Installing GitHub CLI..."
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y gh
fi

# ── 2. Apply secret templates ──────────────────────────────────────

echo ""
echo "==> Applying secret templates..."
"$REPO_DIR/apply-secrets.sh" "$SCRIPT_DIR"

# ── 3. Create volume directories ───────────────────────────────────

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

# ── 4. Start services ──────────────────────────────────────────────

echo ""
echo "==> Starting home automation stack..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d

# ── 5. Install HACS in Home Assistant ──────────────────────────────

echo ""
echo "==> Installing HACS in Home Assistant..."
echo "    Waiting for Home Assistant to start..."
sleep 15
docker exec homeassistant sh -c 'wget -O - https://get.hacs.xyz | bash -'
docker compose -f "$SCRIPT_DIR/docker-compose.yml" restart homeassistant

# ── 6. Interactive steps (last) ────────────────────────────────────

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
echo "==> Setting up Tailscale..."
echo "    Follow the link to authenticate this device."
sudo tailscale up

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
