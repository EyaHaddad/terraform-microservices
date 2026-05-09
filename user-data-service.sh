#!/bin/bash
# Don't use set -e here — Eureka/ActiveMQ waits are best-effort and must not abort
set -uxo pipefail

yum update -y
yum install -y docker curl

systemctl enable docker
systemctl start docker

mkdir -p /opt/ecommerce
cd /opt/ecommerce

echo "Stopping old container..."
docker rm -f ${SERVICE_NAME} || true

if [ "${EUREKA_URL}" != "" ]; then
  echo "Waiting for Eureka server..."

  for i in {1..60}; do
    if curl -sf ${EUREKA_URL}apps > /dev/null; then
      echo "Eureka is reachable!"
      break
    fi

    echo "Eureka not ready yet..."
    sleep 5
  done
fi

if [ "${ACTIVEMQ_URL}" != "" ]; then
  broker_host=$(echo "${ACTIVEMQ_URL}" | sed -E 's#^tcp://([^:]+):([0-9]+).*#\1#')
  broker_port=$(echo "${ACTIVEMQ_URL}" | sed -E 's#^tcp://([^:]+):([0-9]+).*#\2#')

  echo "Waiting for ActiveMQ broker..."
  for i in {1..60}; do
    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$broker_host/$broker_port"; then
      echo "ActiveMQ is reachable!"
      break
    fi

    echo "ActiveMQ not ready yet..."
    sleep 5
  done
fi

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
  -e EUREKA_CLIENT_ENABLED=false \
  -e EUREKA_CLIENT_REGISTER_WITH_EUREKA=false \
  -e EUREKA_CLIENT_FETCH_REGISTRY=false \
  -e SPRING_CLOUD_DISCOVERY_ENABLED=false \
  -e SPRING_ACTIVEMQ_BROKER_URL=${ACTIVEMQ_URL} \
  -e PRODUCT_SERVICE_URL=${PRODUCT_SERVICE_URL} \
  -e CART_SERVICE_URL=${CART_SERVICE_URL} \
  -e SPRING_CLOUD_GATEWAY_DISCOVERY_LOCATOR_ENABLED=false \
  -e SPRING_CLOUD_GATEWAY_ROUTES_0_URI=${PRODUCT_SERVICE_URL} \
  -e SPRING_CLOUD_GATEWAY_ROUTES_1_URI=${CART_SERVICE_URL} \
  ${DOCKER_IMAGE}

echo "Container started successfully"

sleep 15

echo "Running local health check..."

curl http://localhost:${PORT}/ || true
