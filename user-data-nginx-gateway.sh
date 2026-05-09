#!/bin/bash
set -euxo pipefail

yum update -y
amazon-linux-extras install nginx1 -y || yum install -y nginx

cat > /etc/nginx/conf.d/ecommerce-gateway.conf << 'NGINX_EOF'
server {
    listen 8089;

    # Health check endpoint for ALB
    location /health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    location /api/products {
        proxy_pass ${PRODUCT_SERVICE_URL}/api/products;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_read_timeout    60s;
        proxy_send_timeout    60s;
    }

    location /api/cart {
        proxy_pass ${CART_SERVICE_URL}/api/cart;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_read_timeout    60s;
        proxy_send_timeout    60s;
    }

    location / {
        return 200 'Nginx Gateway OK';
        add_header Content-Type text/plain;
    }
}
NGINX_EOF

nginx -t
systemctl enable nginx
systemctl restart nginx

echo "Nginx gateway started successfully"
