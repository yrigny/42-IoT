#!/bin/bash

set -e

echo ">>>>>> Stopping port-forward processes..."
pkill -f "kubectl port-forward" 2>/dev/null || true

echo ">>>>>> Deleting k3d cluster..."
k3d cluster delete mycluster 2>/dev/null || true

echo ">>>>>> Stopping and removing GitLab container..."
docker stop gitlab 2>/dev/null || true
docker rm gitlab 2>/dev/null || true

echo ">>>>>> Removing GitLab data volume..."
docker volume rm gitlab-data 2>/dev/null || true

echo ">>>>>> Removing cloned playground repo..."
rm -rf /tmp/playground
rm -f /tmp/gitlab-token

echo ">>>>>> Removing gitlab.local from /etc/hosts..."
sudo sed -i '/gitlab\.local/d' /etc/hosts 2>/dev/null || true

echo ">>>>>> Pruning unused Docker resources..."
docker system prune -af --volumes 2>/dev/null || true

echo "✅ Cleanup complete. You can now re-run:"
echo "  1. ./scripts/gitlab.sh"
echo "  2. ./scripts/cluster.sh"
