#!/bin/bash

set -eux

echo ">>>>>> Updating package index..."
sudo apt-get update -y
echo ">>>>>> Installing required dependencies..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release snapd

echo ">>>>>> Setting up Docker keyring..."
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
	sudo curl -fsSL https://download.docker.com/linux/debian/gpg | \
	       sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
else
	echo "Docker GPG key already exists. Skipping download."
fi

echo ">>>>>> Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
	$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo ">>>>>> Updating package index again after adding Docker repo..."
sudo apt-get update -y

echo ">>>>>> Installing Docker packages..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER

echo ">>>>>> Docker installed successfully. Running test container..."
sudo docker run hello-world

echo ">>>>>> Setting up kubectl keyring..."
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key \
       -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

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

echo ">>>>>> Installing Helm package..."
sudo snap install helm --classic

echo ">>>>>> Creating k3d cluster for gitlab..."
k3d cluster create mygitlab

echo ">>>>>> Checking cluster status..."
kubectl get nodes

echo ">>>>>> Installing Gitlab in the k3s cluster..."
kubectl create namespace gitlab
helm repo add gitlab https://charts.gitlab.io/
helm repo update

helm upgrade --install gitlab gitlab/gitlab \
      -n gitlab \
      -f https://gitlab.com/gitlab-org/charts/gitlab/raw/master/examples/values-minikube-minimum.yaml \
      --set global.hosts.domain=k3d.gitlab.com \
      --set global.hosts.externalIP=0.0.0.0 \
      --set global.hosts.https=false \
      --timeout 600s

# kubectl wait --for=condition=ready --timeout=1200s pod -l app=webservice -n gitlab
echo ">>>>>> Checking GitLab webservice pod status..."
kubectl get pods -n gitlab -l app=webservice
echo ">>>>>> You can manually watch status using:"
echo "kubectl get pods -n gitlab -w"

# echo ">>>>>> Checking the status of Gitlab pods..."
# kubectl get pods -n gitlab


