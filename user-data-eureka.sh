#!/bin/bash

yum update -y
yum install -y docker curl

systemctl enable docker
systemctl start docker

mkdir -p /opt/ecommerce
cd /opt/ecommerce

echo "Stopping old Eureka container..."
docker rm -f eureka-server || true

echo "Pulling Eureka image..."
docker pull ${eureka_image}

echo "Starting Eureka container..."

docker run -d \
  --name eureka-server \
  --restart unless-stopped \
  -p 8761:8761 \
  -e SPRING_PROFILES_ACTIVE=docker \
  -e SERVER_PORT=8761 \
  -e EUREKA_CLIENT_REGISTER_WITH_EUREKA=false \
  -e EUREKA_CLIENT_FETCH_REGISTRY=false \
  ${eureka_image}

echo "Waiting for Eureka to become available..."

for i in {1..60}; do
  if curl -sf http://localhost:8761/eureka/apps > /dev/null; then
    echo "Eureka is UP!"
    break
  fi

  echo "Eureka not ready yet..."
  sleep 5
done

echo "Eureka container launched successfully"
