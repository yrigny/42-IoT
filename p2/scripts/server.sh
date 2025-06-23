#!/bin/bash

apt-get update && apt-get install -y curl
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.110" sh -
chown vagrant:vagrant /etc/rancher/k3s/k3s.yaml
chmod 644 /etc/rancher/k3s/k3s.yaml
echo 'export PATH=$PATH:/usr/local/bin' >> /home/vagrant/.bashrc
echo 'alias k=kubectl' >> /home/vagrant/.bashrc
kubectl apply -f /vagrant/confs/deployment.yaml
