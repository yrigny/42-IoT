#!/bin/bash

set -e

echo ">>>>>> Creating k3d cluster..."
k3d cluster create mycluster

echo ">>>>>> Checking cluster status..."
kubectl get nodes

echo ">>>>>> Creating namespaces..."
kubectl create namespace argocd
kubectl create namespace dev

echo ">>>>>> Installing Argo CD in the k3s cluster..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side

echo ">>>>>> Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=Available --timeout=300s -n argocd deployment/argocd-server
kubectl wait --for=condition=Available --timeout=300s -n argocd deployment/argocd-repo-server
kubectl wait --for=condition=Ready --timeout=300s -n argocd pod -l app.kubernetes.io/name=argocd-application-controller
kubectl wait --for=condition=Ready --timeout=300s -n argocd pod -l app.kubernetes.io/name=argocd-redis

echo ">>>>>> Checking the status of Argo CD pods..."
kubectl get pods -n argocd

echo ">>>>>> Port-forwarding Argo CD server..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 2>/dev/null &
PF_ARGOCD_PID=$!
printf "\033[0;32mPF_ARGOCD_PID: $PF_ARGOCD_PID\n\033[0m"
sleep 3

echo ">>>>>> Extracting the password of admin for Argo CD..."
password=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
printf "\033[0;32mArgoCD Password: $password\n\033[0m"

echo ">>>>>> Logging in Argo CD admin account..."
argocd login localhost:8080 --username admin --password "$password" --insecure

echo ">>>>>> Connecting GitLab container to k3d network..."
docker network connect k3d-mycluster gitlab 2>/dev/null || true
GITLAB_IP=$(docker inspect -f '{{index .NetworkSettings.Networks "k3d-mycluster" "IPAddress"}}' gitlab)
printf "\033[0;32mGitLab IP (k3d network): $GITLAB_IP\n\033[0m"

if [ -z "$GITLAB_IP" ]; then
  echo "Error: Could not determine GitLab IP address. Is GitLab container running?"
  exit 1
fi

echo ">>>>>> Creating the playground app in ArgoCD..."
# Note: Token in URL is acceptable for this isolated local development environment
argocd app create playground \
  --repo http://root:glpat-argocd-bonus-token@${GITLAB_IP}/root/playground.git \
  --path . \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy auto \
  --insecure

echo ">>>>>> Waiting for 'playground' pod to be ready..."
until [ "$(kubectl get pods -n dev -l app=playground --no-headers 2>/dev/null | wc -l)" -gt 0 ] && \
      kubectl get pods -n dev -l app=playground -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null | grep -q true; do
  echo "Pod not ready yet, sleeping..."
  sleep 2
done

echo ">>>>>> Playground pod is ready!"

echo ">>>>>> Port-forwarding playground app..."
kubectl port-forward svc/playground -n dev 8888:8888 --address 0.0.0.0 2>/dev/null &
PF_APP_PID=$!
printf "\033[0;32mPF_APP_PID: $PF_APP_PID\n\033[0m"

echo ">>>>>> Setup complete!"
echo ">>>>>> ArgoCD UI: http://localhost:8080 (username: admin, password: $password)"
echo ">>>>>> Playground app: http://localhost:8888"
echo ">>>>>> GitLab UI: http://localhost:9080 (username: root, token: glpat-argocd-bonus-token)"
