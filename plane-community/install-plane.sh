#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/opt/plane-selfhost"
APP_DIR="$INSTALL_DIR/plane-app"
HTTP_PORT="${HTTP_PORT:-8080}"
HTTPS_PORT="${HTTPS_PORT:-4430}"
SERVER_IP="${SERVER_IP:-$(hostname -I | awk '{print $1}')}"
WEB_URL="${WEB_URL:-http://${SERVER_IP}:${HTTP_PORT}}"

apt-get update
apt-get install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh -
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

curl -fsSL -o setup.sh https://github.com/makeplane/plane/releases/latest/download/setup.sh
chmod +x setup.sh

# Install Plane compose/env files
printf "1\n8\n" | ./setup.sh || true

if [ ! -f "$APP_DIR/plane.env" ]; then
  echo "ERROR: $APP_DIR/plane.env was not created."
  echo "Run manually: cd $INSTALL_DIR && ./setup.sh"
  exit 1
fi

sed -i \
  -e "s|^LISTEN_HTTP_PORT=.*|LISTEN_HTTP_PORT=${HTTP_PORT}|" \
  -e "s|^LISTEN_HTTPS_PORT=.*|LISTEN_HTTPS_PORT=${HTTPS_PORT}|" \
  -e "s|^WEB_URL=.*|WEB_URL=${WEB_URL}|" \
  -e "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=${WEB_URL}|" \
  "$APP_DIR/plane.env"

# Start Plane
printf "2\n" | ./setup.sh

echo
echo "Plane install complete."
echo "URL: $WEB_URL"
echo "Install dir: $INSTALL_DIR"
