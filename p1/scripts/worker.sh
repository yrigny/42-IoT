#!/bin/bash

TOKEN=$(cat /vagrant/shared/token)
apt-get update && apt-get install -y curl
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=$TOKEN INSTALL_K3S_EXEC="--node-ip=192.168.56.111" sh -
echo 'export PATH=$PATH:/usr/local/bin' >> /home/vagrant/.bashrc
