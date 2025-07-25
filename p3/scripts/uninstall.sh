#!/bin/bash

echo ">>>>>> Removing Docker containers, images, and packages..."
sudo docker container stop $(sudo docker ps -aq) 2>/dev/null
sudo docker container rm $(sudo docker ps -aq) 2>/dev/null
sudo docker image rm $(sudo docker images -q) 2>/dev/null
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt-get autoremove -y
sudo rm -rf /var/lib/docker /var/lib/containerd

echo ">>>>>> Removing Docker keyring and repository..."
sudo rm -f /etc/apt/keyrings/docker.asc
sudo rm -f /etc/apt/sources.list.d/docker.list

echo ">>>>>> Removing kubectl package..."
sudo apt-get purge -y kubectl
sudo apt-get autoremove -y

echo ">>>>>> Removing kubectl keyring and repository..."
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo rm -f /etc/apt/sources.list.d/kubernetes.list

echo ">>>>>> Removing Argo CD CLI..."
sudo rm -f /usr/local/bin/argocd

echo ">>>>>> Removing k3d binary..."
sudo rm -f /usr/local/bin/k3d

echo ">>>>>> Cleaning up APT cache..."
sudo apt-get update -y

echo "✅ Uninstallation complete."

