#!/usr/bin/env bash
# install-docker-compose-in-lxc.sh
set -euo pipefail

# ---- sanity checks ----
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo -i)." >&2
  exit 1
fi

# Helpful hint for Proxmox users
echo "Tip: For Docker in LXC, ensure the container has: privileged=1 (recommended) and features: nesting=1."
echo "Continuing with install..."

# ---- detect package manager / distro ----
if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script supports Debian/Ubuntu (apt). Detected non-apt system." >&2
  exit 2
fi

. /etc/os-release
DIST_ID="${ID:-debian}"
DIST_CODENAME="${VERSION_CODENAME:-}"
DIST_VERSION_ID="${VERSION_ID:-}"

# ---- cleanup old packages (if any) ----
apt-get remove -y docker docker-engine docker.io containerd runc || true

# ---- prerequisites ----
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https \
                   uidmap apparmor fuse-overlayfs

# ---- add Docker’s official GPG key & repo ----
install -m 0755 -d /etc/apt/keyrings
if ! [ -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/${DIST_ID}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

# Prefer VERSION_CODENAME when available; otherwise map Debian/Ubuntu by version id
if [[ -z "$DIST_CODENAME" ]]; then
  # Fallback mapping for common cases
  case "${DIST_ID}:${DIST_VERSION_ID}" in
    debian:12)  DIST_CODENAME="bookworm" ;;
    debian:11)  DIST_CODENAME="bullseye" ;;
    ubuntu:22.04) DIST_CODENAME="jammy" ;;
    ubuntu:24.04) DIST_CODENAME="noble" ;;
    *) echo "Unknown distro codename. You may need to set DIST_CODENAME manually."; exit 3 ;;
  esac
fi

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DIST_ID} ${DIST_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

# ---- install Docker Engine + Buildx + Compose v2 plugin ----
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ---- optional daemon defaults (safe, small logs, overlay2) ----
mkdir -p /etc/docker
if [[ ! -f /etc/docker/daemon.json ]]; then
  cat >/etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "storage-driver": "overlay2"
}
JSON
fi

# ---- enable & start docker ----
if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
  systemctl enable --now docker
else
  service docker start || true
fi

# ---- add invoking user to docker group (so you can run without sudo) ----
INVOKER="${SUDO_USER:-}"
if [[ -n "$INVOKER" ]]; then
  usermod -aG docker "$INVOKER" || true
  echo "User '$INVOKER' added to 'docker' group. Log out/in to apply."
fi

# ---- quick smoke tests ----
echo "Docker version: $(docker --version || true)"
echo "Compose v2 version: $(docker compose version || true)"

echo "Running a quick hello-world container to verify..."
docker run --rm hello-world || {
  echo "Note: If this fails inside LXC, ensure 'nesting=1' and that the container is privileged." >&2
}

cat <<'EOF'

✅ Done!

Use Docker Compose via:
  docker compose version
  docker compose up -d

Quick test:
  mkdir -p ~/compose-test && cd ~/compose-test
  cat >docker-compose.yml <<YAML
services:
  whoami:
    image: traefik/whoami
    ports:
      - "8080:80"
YAML
  docker compose up -d
  curl http://127.0.0.1:8080

If you see JSON, Compose works. If you hit any overlay/cgroups errors,
ensure the LXC has:
  - Privileged container (recommended for Docker-in-LXC)
  - Features: nesting=1
  - On Proxmox host: cgroup v2 enabled (default on recent PVE)

EOF
