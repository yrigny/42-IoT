#!/bin/bash

echo ">>>>>> Creating k3s cluster..."
k3d cluster create mycluster

echo ">>>>>> Checking cluster status..."
kubectl get nodes

echo ">>>>>> Installing Argo CD in the k3s cluster..."
kubectl create namespace argocd
kubectl create namespace dev
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ">>>>>> Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=Available --timeout=300s -n argocd deployment/argocd-server
kubectl wait --for=condition=Available --timeout=300s -n argocd deployment/argocd-repo-server
kubectl wait --for=condition=Available --timeout=300s -n argocd deployment/argocd-application-controller
kubectl wait --for=condition=Ready --timeout=300s -n argocd pod -l app.kubernetes.io/name=argocd-redis

echo ">>>>>> Checking the status of Argo CD pods..."
kubectl get pods -n argocd

echo ">>>>>> Accessing the Argo CD API server by port forwarding..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 2>/dev/null &
printf "\033[0;32mPF_ARGOCD_PID: $!\n\033[0m"
sleep 3

echo ">>>>>> Extracting the password of admin for Argo CD..."
password=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
printf "\033[0;32mPassword: $password\n\033[0m"

echo ">>>>>> Logging in Argo CD admin account..."
argocd login localhost:8080 --username admin --password "$password" --insecure

echo ">>>>>> Creating the playground example app..."
argocd app create playground \
	--repo https://github.com/yrigny/42-IoT.git \
	--path ./p3/playground \
	--dest-server https://kubernetes.default.svc \
	--dest-namespace dev \
	--sync-policy auto \
	--insecure

echo ">>>>>> Waiting for 'playground' pod to be ready..."
until kubectl get pods -n dev -l app=playground -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null | grep -q true; do
  echo "Pod not ready yet, sleeping..."
  sleep 2
done

echo ">>>>>> Accessing the example app by port forwarding..."
kubectl port-forward svc/playground -n dev 8888:8888 2>/dev/null &
printf "\033[0;32mPF_APP_PID: $!\n\033[0m"
