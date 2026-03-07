#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Home server setup"
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

# ── 2. Interactive steps (last) ────────────────────────────────────

echo ""
echo "========================================="
echo "  Interactive setup steps"
echo "========================================="
echo ""

echo "==> Setting up Tailscale..."
echo "    Follow the link to authenticate this device."
sudo tailscale up

echo ""
echo "========================================="
echo "  Base setup complete!"
echo "========================================="
echo ""
echo "  Installed:"
echo "    - Docker"
echo "    - Tailscale"
echo "    - GitHub CLI"
echo "    - System utilities (curl, git, vim, tmux, zsh, envsubst)"
echo ""
echo "  Next: run a recipe setup script (e.g. home-automation/setup.sh)"
