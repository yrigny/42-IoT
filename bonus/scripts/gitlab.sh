#!/bin/bash

set -e

# 1. Add gitlab.local to /etc/hosts FIRST so the script can resolve it internally
echo ">>>>>> Adding gitlab.local to /etc/hosts..."
if ! grep -q "gitlab.local" /etc/hosts; then
  echo "127.0.0.1 gitlab.local" | sudo tee -a /etc/hosts
fi

echo ">>>>>> Deploying GitLab CE as a Docker container..."
# Increased max_threads and workers slightly to prevent boot deadlocks
docker run -d \
  --name gitlab \
  --hostname gitlab.local \
  --memory 4g \
  --shm-size 256m \
  -p 9080:80 \
  -v gitlab-data:/var/opt/gitlab \
  --restart unless-stopped \
  -e GITLAB_OMNIBUS_CONFIG="
    external_url 'http://gitlab.local';
    gitlab_rails['monitoring_whitelist'] = ['127.0.0.0/8', '172.0.0.0/8'];
    prometheus_monitoring['enable'] = false;
    alertmanager['enable'] = false;
    node_exporter['enable'] = false;
    redis_exporter['enable'] = false;
    postgres_exporter['enable'] = false;
    gitlab_exporter['enable'] = false;
    prometheus['enable'] = false;
    puma['worker_processes'] = 2;
    puma['min_threads'] = 1;
    puma['max_threads'] = 2;
    sidekiq['concurrency'] = 5;
    postgresql['shared_buffers'] = '128MB';
    postgresql['max_worker_processes'] = 4;
    registry['enable'] = false;
    gitlab_pages['enable'] = false;
  " \
  gitlab/gitlab-ce:latest

echo ">>>>>> Waiting for GitLab to become healthy..."
echo "       (Checking http://gitlab.local:9080/users/sign_in)"

timeout=600
elapsed=0
# We check the sign-in page directly. If it returns HTTP 200, the stack is up.
# We use -H 'Host: gitlab.local' to force the correct routing.
until curl -sf -o /dev/null -H "Host: gitlab.local" http://localhost:9080/users/sign_in; do
  if [ $elapsed -ge $timeout ]; then
    echo "GitLab failed to start within $timeout seconds"
    docker logs --tail 20 gitlab
    exit 1
  fi
  echo "GitLab not ready yet... ($elapsed/$timeout seconds)"
  sleep 10
  elapsed=$((elapsed + 10))
done

echo ">>>>>> GitLab is healthy!"

echo ">>>>>> Extracting initial root password..."
sleep 10 # Give it a moment to flush the password file to disk
initial_password=$(docker exec gitlab cat /etc/gitlab/initial_root_password 2>/dev/null | grep "Password:" | awk '{print $2}')

if [ -n "$initial_password" ]; then
  printf "\033[0;32mInitial root password: $initial_password\n\033[0m"
else
  echo "Warning: Could not extract initial root password. It might still be generating."
fi

echo ">>>>>> Creating personal access token for ArgoCD..."
# We wait for the Rails console to be ready
until docker exec gitlab gitlab-rails runner "puts 'Rails is ready'" > /dev/null 2>&1; do
  echo "Waiting for Rails console to accept commands..."
  sleep 10
done

docker exec gitlab gitlab-rails runner "
  begin
    user = User.find_by_username('root')
    token = user.personal_access_tokens.create(
      name: 'argocd-token',
      scopes: ['api', 'read_repository', 'write_repository'],
      expires_at: 365.days.from_now
    )
    token.set_token('glpat-argocd-bonus-token')
    token.save!
    puts 'Token created successfully'
  rescue => e
    puts 'Error creating token: ' + e.message
  end
"

echo ">>>>>> Token created: glpat-argocd-bonus-token"
echo "glpat-argocd-bonus-token" > /tmp/gitlab-token
chmod 600 /tmp/gitlab-token

echo ">>>>>> Creating playground project in GitLab..."
# Use the Host header here too, just in case
curl -s -H "PRIVATE-TOKEN: glpat-argocd-bonus-token" \
     -H "Host: gitlab.local" \
     "http://localhost:9080/api/v4/projects" \
     -d "name=playground&visibility=public&initialize_with_readme=true"

echo ""
echo ">>>>>> Waiting for project to be fully initialized..."
sleep 5

echo ">>>>>> Cloning playground project and adding K8s manifests..."
cd /tmp
rm -rf playground
git config --global user.email "argocd@bonus.local"
git config --global user.name "ArgoCD Bonus"

# We must use the IP 127.0.0.1 directly to bypass potential localhost resolution issues with git
# but we map the port 9080
git clone http://root:glpat-argocd-bonus-token@127.0.0.1:9080/root/playground.git

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
echo ">>>>>> Access GitLab at: http://gitlab.local:9080"
echo ">>>>>> Username: root"
echo ">>>>>> Token: glpat-argocd-bonus-token"
echo ">>>>>> Project URL: http://gitlab.local:9080/root/playground"
