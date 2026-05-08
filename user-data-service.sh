#!/bin/bash

yum update -y
yum install -y docker curl

systemctl enable docker
systemctl start docker

mkdir -p /opt/ecommerce
cd /opt/ecommerce

echo "Stopping old container..."
docker rm -f ${SERVICE_NAME} || true

echo "Waiting for Eureka server..."

for i in {1..60}; do
  if curl -sf ${EUREKA_URL}apps > /dev/null; then
    echo "Eureka is reachable!"
    break
  fi

  echo "Eureka not ready yet..."
  sleep 5
done

echo "Pulling Docker image..."
docker pull ${DOCKER_IMAGE}

echo "Starting container..."

docker run -d \
  --name ${SERVICE_NAME} \
  --restart unless-stopped \
  -p ${PORT}:${PORT} \
  -e SPRING_PROFILES_ACTIVE=docker \
  -e SERVER_PORT=${PORT} \
  -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=${EUREKA_URL} \
  -e MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,info \
  -e MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS=always \
  -e SPRING_ACTIVEMQ_BROKER_URL=${ACTIVEMQ_URL} \
  ${DOCKER_IMAGE}

echo "Container started successfully"

sleep 15

echo "Running local health check..."

curl http://localhost:${PORT}/ || true