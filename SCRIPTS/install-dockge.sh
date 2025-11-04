#!/usr/bin/env bash
set -euo pipefail

# === Config ===
DOCKGE_DIR="/opt/dockge"
STACKS_DIR="/opt/stacks"
DOCKGE_PORT="5001"
COMPOSE_URL="https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml"

# === Setup ===
echo "==> Setting up Dockge at $DOCKGE_DIR"
sudo mkdir -p "$DOCKGE_DIR" "$STACKS_DIR"
sudo chown -R "$USER":"$USER" "$DOCKGE_DIR" "$STACKS_DIR"

cd "$DOCKGE_DIR"

# === Download compose.yaml ===
echo "==> Downloading compose file..."
curl -fsSL "$COMPOSE_URL" -o compose.yaml

# === Customize port and stacks path ===
echo "==> Updating compose file with your configuration..."
sed -i "s|/opt/stacks|$STACKS_DIR|g" compose.yaml
sed -i "s|5001:5001|$DOCKGE_PORT:5001|g" compose.yaml

# === Launch Dockge ===
echo "==> Starting Dockge container..."
docker compose up -d

# === Verify ===
if docker ps --filter "name=dockge" --filter "status=running" | grep -q "dockge"; then
  echo -e "\033[0;32m✅ Dockge is running! Access it at: http://$(hostname -I | awk '{print $1}'):$DOCKGE_PORT\033[0m"
else
  echo -e "\033[0;31m❌ Dockge failed to start. Check logs with:\033[0m"
  echo "    docker compose logs"
fi
