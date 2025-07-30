#!/bin/bash

echo ">>>>>> Updating package index..."
sudo apt-get update -y
echo ">>>>>> Installing required dependencies..."
sudo apt-get install -y ca-certificates curl gnupg

echo ">>>>>> Setting up Docker keyring..."
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc
else
	echo "Docker GPG key already exists. Skipping download."
fi

echo ">>>>>> Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo ">>>>>> Updating package index again after adding Docker repo..."
sudo apt-get update -y

echo ">>>>>> Installing Docker packages..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER

echo ">>>>>> Docker installed successfully. Running test container..."
sudo docker run hello-world

echo ">>>>>> Setting up kubectl keyring..."
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

echo ">>>>>> Adding kubectl repository..."
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly

echo ">>>>>> Updating package index again after adding kubectl repo..."
sudo apt-get update -y

echo ">>>>>> Installing kubectl package..."
sudo apt-get install -y kubectl
echo 'alias k=kubectl' >> ~/.bashrc && source ~/.bashrc

echo ">>>>>> Installing k3d package..."
sudo curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo ">>>>>> Installing Argo CD CLI..."
sudo curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
sudo rm argocd-linux-amd64

