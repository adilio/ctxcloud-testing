#!/bin/bash
# User data for docker-container-host scenario
# Installs Docker, deploys a container with risky settings

set -e

# Update & install dependencies
apt-get update -y
apt-get install -y docker.io

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Create a sample app directory
mkdir -p /opt/risky-app
cat << 'EOF' > /opt/risky-app/app.sh
#!/bin/bash
while true; do
  echo -e "HTTP/1.1 200 OK\n\nHello from risky container — $(hostname)" | nc -lp 8080 -q 1
done
EOF
chmod +x /opt/risky-app/app.sh

# Ensure secret file exists on host before container start
echo "SensitiveToken=sk_live_ABC123LEAK" > /opt/risky-app/secret.txt

# Build and run the container:
# - Runs as root (default)
# - Mounts host /etc directory (risk of credential/config theft)
# - Mounts risky-app dir to share app + secrets
# - Uses host network (amplifies risk; may not work on Docker Desktop for Mac/Windows)
# - Accessible on 0.0.0.0:8080
docker run -d \
  --name risky-container \
  --network host \
  -v /etc:/host-etc:ro \
  -v /opt/risky-app:/opt/risky-app:ro \
  ubuntu:20.04 \
  /bin/bash -c "apt-get update && apt-get install -y netcat && /opt/risky-app/app.sh"