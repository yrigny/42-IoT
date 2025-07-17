#!/bin/bash
set -euo pipefail

# Optional: uncomment for debug
# set -x

echo "🚫 Stopping Docker services if running..."
sudo systemctl stop docker || true
sudo systemctl stop containerd || true

echo "🧼 Removing Docker packages..."
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras || true

echo "🗑️ Removing residual config files..."
sudo apt-get autoremove -y --purge
sudo apt-get clean

echo "📁 Deleting Docker APT source list and keyring..."
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.asc

echo "🧹 Removing Docker-related directories (excluding user volumes/images)..."
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# OPTIONAL: Uncomment if you want to remove ALL images, volumes, configs
# echo "⚠️ Removing all Docker volumes, images, and configuration (use with caution)"
# sudo rm -rf ~/.docker
# sudo rm -rf /etc/docker
# sudo rm -rf /var/run/docker.sock

echo "✅ Docker has been completely removed."

