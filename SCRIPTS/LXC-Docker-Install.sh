#!/usr/bin/env bash
set -euo pipefail

# Ubuntu 24.04 LXC
# Purpose:
# - Install Docker CE
# - Install NVIDIA Container Toolkit
# - Configure Docker for NVIDIA GPUs inside LXC
# - Apply the no-cgroups workaround required for many Proxmox LXC GPU setups
# - Validate GPU access from Docker
#
# Run as root.

DOCKER_CUDA_TEST_IMAGE="nvidia/cuda:12.8.0-base-ubuntu24.04"

echo "==> Installing base packages"
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

echo "==> Adding Docker apt repository"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable
EOF

echo "==> Adding NVIDIA Container Toolkit apt repository"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  > /etc/apt/sources.list.d/nvidia-container-toolkit.list

echo "==> Installing Docker CE and NVIDIA Container Toolkit"
apt-get update
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  nvidia-container-toolkit

echo "==> Enabling Docker"
systemctl enable --now docker

echo "==> Configuring NVIDIA runtime for Docker"
nvidia-ctk runtime configure --runtime=docker

echo "==> Applying LXC workaround: disable NVIDIA cgroup management"
nvidia-ctk config --set nvidia-container-cli.no-cgroups=true --in-place

echo "==> Restarting Docker"
systemctl restart docker

echo
echo "==> Current NVIDIA runtime config"
grep -A20 '^\[nvidia-container-cli\]' /etc/nvidia-container-runtime/config.toml || true

echo
echo "==> Current Docker daemon config"
cat /etc/docker/daemon.json || true

echo
echo "==> Verifying GPU visibility in LXC"
nvidia-smi

echo
echo "==> Verifying GPU visibility in Docker"
docker run --rm --gpus all "${DOCKER_CUDA_TEST_IMAGE}" nvidia-smi

echo
echo "Success."
echo "Docker + NVIDIA toolkit + LXC GPU workaround are configured."
