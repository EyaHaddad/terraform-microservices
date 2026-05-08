#!/bin/bash
set -euxo pipefail

yum update -y
yum install -y docker curl
systemctl enable docker
systemctl start docker

docker rm -f activemq || true

docker pull ${activemq_image}

docker run -d \
  --name activemq \
  --restart unless-stopped \
  -p 61616:61616 \
  -p 8161:8161 \
  ${activemq_image}

for i in {1..60}; do
  if curl -sf http://localhost:8161/ > /dev/null; then
    echo "ActiveMQ is UP!"
    exit 0
  fi

  echo "ActiveMQ not ready yet..."
  docker ps -a
  docker logs --tail 50 activemq || true
  sleep 5
done

echo "ActiveMQ did not become ready in time"
docker ps -a
docker logs activemq || true
exit 1
