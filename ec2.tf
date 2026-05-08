# EC2 Instances for Microservices

# Security Group for EC2 instances
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "EC2 SG - ALB access only"
  vpc_id      = aws_vpc.main.id

  # SSH (debug only)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ALB → Product Service
  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # ALB → Cart Service
  ingress {
    from_port       = 8082
    to_port         = 8082
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # ALB → API Gateway
  ingress {
    from_port       = 8089
    to_port         = 8089
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 8761
    to_port     = 8761
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 61616
    to_port     = 61616
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress { # ActiveMQ Web Console (TEMP DEV ONLY)
    from_port   = 8161
    to_port     = 8161
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # TEMP DEV ONLY
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

locals {
  eureka_url   = "http://${aws_instance.eureka_server.private_ip}:8761/eureka/"
  activemq_url = "tcp://${aws_instance.activemq.private_ip}:61616"
}

# Data source for existing EC2InstanceRole
data "aws_iam_role" "ec2_instance_role" {
  name = "LabRole"
}

# EC2 Instance for Eureka Server
resource "aws_instance" "eureka_server" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.ec2_key.key_name
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(templatefile("${path.module}/user-data-eureka.sh", {
    eureka_image = var.container_images.eureka
  }))

  tags = {
    Name = "${var.project_name}-eureka-server"
  }
}

# EC2 Instance for Product Service
resource "aws_instance" "product_service" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.ec2_key.key_name
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(templatefile("${path.module}/user-data-service.sh", {
    SERVICE_NAME = "product-service"
    DOCKER_IMAGE = var.container_images.product
    PORT         = var.container_port_product
    EUREKA_URL   = local.eureka_url
    ACTIVEMQ_URL = local.activemq_url
  }))

  tags = {
    Name = "${var.project_name}-product-service"
  }

  depends_on = [aws_instance.eureka_server, aws_instance.activemq]
}

# EC2 Instance for Cart Service
resource "aws_instance" "cart_service" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.ec2_key.key_name
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(templatefile("${path.module}/user-data-service.sh", {
    SERVICE_NAME = "cart-service"
    DOCKER_IMAGE = var.container_images.cart
    PORT         = var.container_port_cart
    EUREKA_URL   = local.eureka_url
    ACTIVEMQ_URL = local.activemq_url
  }))

  tags = {
    Name = "${var.project_name}-cart-service"
  }

  depends_on = [aws_instance.eureka_server, aws_instance.activemq]
}

# EC2 Instance for API Gateway
resource "aws_instance" "api_gateway" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.ec2_key.key_name
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(templatefile("${path.module}/user-data-service.sh", {
    SERVICE_NAME = "api-gateway"
    DOCKER_IMAGE = var.container_images.api_gateway
    PORT         = var.container_port_gateway
    EUREKA_URL   = local.eureka_url
    ACTIVEMQ_URL = local.activemq_url
  }))

  tags = {
    Name = "${var.project_name}-api-gateway"
  }

  depends_on = [aws_instance.eureka_server]
}

# EC2 Instance for ActiveMQ
resource "aws_instance" "activemq" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.ec2_key.key_name
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = file("${path.module}/user-data-activemq.sh")

  tags = {
    Name = "${var.project_name}-activemq"
  }
}

# EC2 Key Pair
resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.project_name}-ec2-key-2026-1"
  public_key = tls_private_key.ec2.public_key_openssh

  tags = {
    Name = "${var.project_name}-ec2-key-2026-1"
  }
}

# Save private key locally
resource "local_file" "ec2_private_key" {
  content         = tls_private_key.ec2.private_key_pem
  filename        = "${path.module}/${var.project_name}-ec2-key-2026-1.pem"
  file_permission = "0600"
}

# Data source for Amazon Linux 2
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}