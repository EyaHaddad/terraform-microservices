#!/bin/bash
set -e

yum update -y
yum install docker -y
systemctl start docker
systemctl enable docker

docker rm -f activemq || true

docker pull ${activemq_image}

docker run -d \
  --name activemq \
  --restart unless-stopped \
  -p 61616:61616 \
  -p 8161:8161 \
  ${activemq_image}
