#!/bin/bash

echo ">>>>>> Creating k3s cluster..."
k3d cluster create mycluster

echo ">>>>>> Checking cluster status..."
kubectl get nodes

echo ">>>>>> Installing Argo CD in the k3s cluster..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ">>>>>> Checking the status of Argo CD pods..."
kubectl get pods -n argocd

echo ">>>>>> Accessing the Argo CD API server by port forwarding..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 &
password=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
argocd admin $(password) -n argocd

echo ">>>>>> Changing the password of admin for Argo CD..."
new_password=yifanrigny
sudo apt install -y expect
expect <<EOF
spawn argocd account update-password
expect "*** Enter password of currently logged in user (admin):"
send "$password\r"
expect "*** Enter new password for user admin:"
send "$new_password\r"
expect "*** Confirm new password for user admin:"
send "$new_password\r"
expect eof
EOF

echo ">>>>>> Creating the playground example app..."
argocd app create playground \
	--repo https://github.com/yrigny/42-IoT \
	--path playground \
	--dest-server https://kubernetes.default.svc \
	--dest-namespace dev \
	--sync-policy auto

