#!/bin/bash
set -e

yum update -y
yum install docker -y
systemctl start docker
systemctl enable docker

docker pull apache/activemq-classic:latest

docker run -d \
  --name activemq \
  -p 61616:61616 \
  -p 8161:8161 \
  apache/activemq-classic:latest