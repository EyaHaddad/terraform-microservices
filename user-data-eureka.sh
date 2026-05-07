#!/bin/bash
set -e

# Update system
yum update -y
yum install -y java-17-amazon-corretto curl wget

# Create app directory
mkdir -p /opt/ecommerce
cd /opt/ecommerce

# Download JAR file from S3
echo "Downloading Eureka Server JAR from S3..."
aws s3 cp s3://${s3_bucket}/${jar_file} . --region us-east-1

if [ ! -f "${jar_file}" ]; then
  echo "ERROR: Failed to download JAR file ${jar_file}"
  exit 1
fi

# Make JAR executable
chmod +x ${jar_file}
echo "Downloaded: $(ls -lh ${jar_file})"

# Wait for system to fully initialize
sleep 10

# Start Eureka Server
echo "Starting Eureka Server on port ${port}..."
nohup java -Xmx256m -Xms128m -jar ${jar_file} \
  -Dserver.port=${port} \
  -Deureka.instance.hostname=$(hostname -f) \
  > /var/log/eureka-server.log 2>&1 &

sleep 3
if pgrep -f "eureka-server.*jar" > /dev/null; then
  echo "Eureka Server started successfully"
else
  echo "WARNING: Eureka Server process not found"
fi

