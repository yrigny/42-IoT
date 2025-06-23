#!/bin/bash

apt-get update && apt-get install -y curl
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.110" sh -
mkdir -p /vagrant/shared
cp /var/lib/rancher/k3s/server/node-token /vagrant/shared/token
chmod 644 /etc/rancher/k3s/k3s.yaml
echo 'export PATH=$PATH:/usr/local/bin' >> /home/vagrant/.bashrc
echo 'alias k=kubectl' >> /home/vagrant/.bashrc
 
