#!/bin/bash

set -e

echo ">>>>>> Deploying GitLab CE as a Docker container..."
docker run -d \
  --name gitlab \
  --hostname gitlab.local \
  --memory 4g \
  -p 9080:80 \
  -v gitlab-data:/var/opt/gitlab \
  --restart unless-stopped \
  -e GITLAB_OMNIBUS_CONFIG="
    external_url 'http://gitlab.local';
    prometheus_monitoring['enable'] = false;
    grafana['enable'] = false;
    alertmanager['enable'] = false;
    node_exporter['enable'] = false;
    redis_exporter['enable'] = false;
    postgres_exporter['enable'] = false;
    gitlab_exporter['enable'] = false;
    prometheus['enable'] = false;
    puma['worker_processes'] = 0;
    puma['min_threads'] = 1;
    puma['max_threads'] = 2;
    sidekiq['concurrency'] = 5;
    postgresql['shared_buffers'] = '128MB';
    postgresql['max_worker_processes'] = 4;
    registry['enable'] = false;
    gitlab_pages['enable'] = false;
  " \
  gitlab/gitlab-ce:latest

echo ">>>>>> Waiting for GitLab to become healthy (this may take up to 10 minutes)..."
timeout=600
elapsed=0
until curl -sf http://localhost:9080/-/health > /dev/null 2>&1; do
  if [ $elapsed -ge $timeout ]; then
    echo "GitLab failed to start within $timeout seconds"
    exit 1
  fi
  echo "GitLab not ready yet, waiting... ($elapsed/$timeout seconds)"
  sleep 10
  elapsed=$((elapsed + 10))
done

echo ">>>>>> GitLab is healthy!"

echo ">>>>>> Extracting initial root password..."
sleep 5  # Give it a moment to ensure the password file is written
initial_password=$(docker exec gitlab cat /etc/gitlab/initial_root_password 2>/dev/null | grep "Password:" | awk '{print $2}')
if [ -n "$initial_password" ]; then
  printf "\033[0;32mInitial root password: $initial_password\n\033[0m"
else
  echo "Warning: Could not extract initial root password. It may have expired."
fi

echo ">>>>>> Creating personal access token for ArgoCD..."
# Note: Using a fixed token for simplicity in this local development environment
# In production, use randomly generated tokens with secure storage
docker exec gitlab gitlab-rails runner "
  token = User.find_by_username('root').personal_access_tokens.create(
    name: 'argocd-token',
    scopes: ['api', 'read_repository', 'write_repository'],
    expires_at: 365.days.from_now
  );
  token.set_token('glpat-argocd-bonus-token');
  token.save!
  puts token.token
"

echo ">>>>>> Token created: glpat-argocd-bonus-token"
echo "glpat-argocd-bonus-token" > /tmp/gitlab-token
chmod 600 /tmp/gitlab-token

echo ">>>>>> Creating playground project in GitLab..."
curl -s -H "PRIVATE-TOKEN: glpat-argocd-bonus-token" \
  "http://localhost:9080/api/v4/projects" \
  -d "name=playground&visibility=public&initialize_with_readme=true"

echo ""
echo ">>>>>> Adding gitlab.local to /etc/hosts..."
if ! grep -q "gitlab.local" /etc/hosts; then
  echo "127.0.0.1 gitlab.local" | sudo tee -a /etc/hosts
fi

echo ">>>>>> Waiting for project to be fully initialized..."
sleep 5

echo ">>>>>> Cloning playground project and adding K8s manifests..."
cd /tmp
rm -rf playground
git config --global user.email "argocd@bonus.local"
git config --global user.name "ArgoCD Bonus"
# Note: Token in URL is acceptable for this isolated local development environment
git clone http://root:glpat-argocd-bonus-token@localhost:9080/root/playground.git

cd playground

echo ">>>>>> Creating deployment.yaml with playground manifests..."
cat > deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: playground
spec:
  replicas: 1
  selector:
    matchLabels: 
      app: playground
  template:
    metadata:
      labels:
        app: playground
    spec:
      containers:
        - image: wil42/playground:v1
          name: playground
          ports:
            - containerPort: 8888
---
apiVersion: v1
kind: Service
metadata:
  name: playground
spec:
  ports:
  - port: 8888
    targetPort: 8888
  selector:
    app: playground
EOF

git add deployment.yaml
git commit -m "Add playground deployment manifests"
git push origin main

echo ">>>>>> GitLab setup complete!"
echo ">>>>>> Access GitLab at: http://localhost:9080"
echo ">>>>>> Username: root"
echo ">>>>>> Token: glpat-argocd-bonus-token"
echo ">>>>>> Project URL: http://localhost:9080/root/playground"
