#!/bin/bash
set -e

# Update system
yum update -y
yum install -y java-17-amazon-corretto curl wget

# Create app directory
mkdir -p /opt/ecommerce
cd /opt/ecommerce

# Download JAR file from S3
echo "Downloading ${jar_file} from S3..."
aws s3 cp s3://${s3_bucket}/${jar_file} . --region us-east-1

if [ ! -f "${jar_file}" ]; then
  echo "ERROR: Failed to download JAR file ${jar_file}"
  exit 1
fi

# Make JAR executable
chmod +x ${jar_file}
echo "Downloaded: $(ls -lh ${jar_file})"

# Wait for Eureka Server to be ready
echo "Waiting for Eureka Server to be ready at http://${eureka_server}/eureka/..."
for i in {1..30}; do
  if curl -f "http://${eureka_server}/eureka/apps" 2>/dev/null | grep -q "applications"; then
    echo "Eureka Server is ready!"
    break
  fi
  echo "Attempt $i: Eureka not ready, waiting..."
  sleep 2
done

# Start Microservice
echo "Starting service ${jar_file} on port ${port}..."
nohup java -Xmx256m -Xms128m -jar ${jar_file} \
  -Dserver.port=${port} \
  -Deureka.client.serviceUrl.defaultZone=http://${eureka_server}/eureka/ \
  -Deureka.instance.hostname=$(hostname -f) \
  > /var/log/microservice.log 2>&1 &

sleep 3
if pgrep -f "${jar_file}" > /dev/null; then
  echo "Service started successfully on port ${port}"
else
  echo "WARNING: Service process not found"
fi
