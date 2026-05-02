cat > install-plane-fixed.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/opt/plane-selfhost"
HTTP_PORT="${HTTP_PORT:-8080}"
HTTPS_PORT="${HTTPS_PORT:-4430}"
SERVER_IP="${SERVER_IP:-$(hostname -I | awk '{print $1}')}"
WEB_URL="${WEB_URL:-http://${SERVER_IP}:${HTTP_PORT}}"

apt-get update
apt-get install -y curl ca-certificates python3 jq

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh -
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

curl -fsSL -o setup.sh https://github.com/makeplane/plane/releases/latest/download/setup.sh
chmod +x setup.sh

# Patch broken release parsing in Plane setup script
LATEST_RELEASE="$(curl -fsSL https://api.github.com/repos/makeplane/plane/releases/latest | jq -r .tag_name)"
sed -i "s|^export APP_RELEASE=.*|export APP_RELEASE=${LATEST_RELEASE}|" setup.sh

# Install files
printf "1\n8\n" | ./setup.sh || true

ENV_FILE="$INSTALL_DIR/plane-app/plane.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE was not created."
  exit 1
fi

sed -i \
  -e "s|^LISTEN_HTTP_PORT=.*|LISTEN_HTTP_PORT=${HTTP_PORT}|" \
  -e "s|^LISTEN_HTTPS_PORT=.*|LISTEN_HTTPS_PORT=${HTTPS_PORT}|" \
  -e "s|^WEB_URL=.*|WEB_URL=${WEB_URL}|" \
  -e "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=${WEB_URL}|" \
  "$ENV_FILE"

# Start services
printf "2\n" | ./setup.sh

echo
echo "Plane install complete:"
echo "$WEB_URL"
EOF

chmod +x install-plane-fixed.sh
sudo ./install-plane-fixed.sh
