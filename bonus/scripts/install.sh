#!/bin/bash

set -e

echo ">>>>>> Updating package index..."
sudo apt-get update -y
echo ">>>>>> Installing required dependencies..."
sudo apt-get install -y ca-certificates curl gnupg git

echo ">>>>>> Setting up Docker keyring..."
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
	sudo curl -fsSL https://download.docker.com/linux/debian/gpg | \
	       sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
else
	echo "Docker GPG key already exists. Skipping download."
fi

echo ">>>>>> Detecting OS for Docker repository..."
if [ -f /etc/os-release ]; then
	. /etc/os-release
	OS_ID=$ID
else
	echo "Cannot detect OS. Assuming Debian."
	OS_ID="debian"
fi

echo ">>>>>> Adding Docker repository for $OS_ID..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID \
	$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo ">>>>>> Updating package index again after adding Docker repo..."
sudo apt-get update -y

echo ">>>>>> Installing Docker packages..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker vagrant

echo ">>>>>> Docker installed successfully. Running test container..."
sudo docker run hello-world

echo ">>>>>> Setting up kubectl keyring..."
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | \
       sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo ">>>>>> Adding kubectl repository..."
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

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

echo ">>>>>> Installation complete!"
echo ">>>>>> Next steps:"
echo "  1. Run 'sudo su - vagrant' to switch to vagrant user"
echo "  2. Run './scripts/gitlab.sh' to deploy GitLab"
echo "  3. Run './scripts/cluster.sh' to create k3d cluster and setup ArgoCD"

