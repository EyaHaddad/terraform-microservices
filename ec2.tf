# EC2 Instances for Microservices

# Security Group for EC2 instances
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  # Allow inbound SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound from ALB for API Gateway
  ingress {
    from_port       = var.container_port_gateway
    to_port         = var.container_port_gateway
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow inbound for Product Service
  ingress {
    from_port       = var.container_port_product
    to_port         = var.container_port_product
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow inbound for Cart Service
  ingress {
    from_port       = var.container_port_cart
    to_port         = var.container_port_cart
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow inbound for Eureka Server
  ingress {
    from_port       = var.container_port_eureka
    to_port         = var.container_port_eureka
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow inbound between EC2 instances
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  # Allow outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# Data source for existing EC2InstanceRole
data "aws_iam_role" "ec2_instance_role" {
  name = "LabRole"
}

# Use existing IAM instance profile
data "aws_iam_instance_profile" "ec2_profile" {
  name = "LabInstanceProfile"
}

# EC2 Instance for Eureka Server
resource "aws_instance" "eureka_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.ec2_key.key_name
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = data.aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(templatefile("${path.module}/user-data-eureka.sh", {
    jar_file = "eureka-server-0.0.1-SNAPSHOT.jar"
    port     = var.container_port_eureka
    s3_bucket = var.jar_bucket_name
  }))

  tags = {
    Name = "${var.project_name}-eureka-server"
  }

  depends_on = [aws_internet_gateway.main]
}

# EC2 Instance for Product Service
resource "aws_instance" "product_service" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.ec2_key.key_name
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = data.aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(templatefile("${path.module}/user-data-service.sh", {
    jar_file       = "product-service-0.0.1-SNAPSHOT.jar"
    port           = var.container_port_product
    eureka_server  = "${aws_instance.eureka_server.private_ip}:${var.container_port_eureka}"
    s3_bucket      = var.jar_bucket_name
  }))

  tags = {
    Name = "${var.project_name}-product-service"
  }

  depends_on = [aws_instance.eureka_server]
}

# EC2 Instance for Cart Service
resource "aws_instance" "cart_service" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.ec2_key.key_name
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = data.aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(templatefile("${path.module}/user-data-service.sh", {
    jar_file       = "cart-service-0.0.1-SNAPSHOT.jar"
    port           = var.container_port_cart
    eureka_server  = "${aws_instance.eureka_server.private_ip}:${var.container_port_eureka}"
    s3_bucket      = var.jar_bucket_name
  }))

  tags = {
    Name = "${var.project_name}-cart-service"
  }

  depends_on = [aws_instance.eureka_server]
}

# EC2 Instance for API Gateway
resource "aws_instance" "api_gateway" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.ec2_key.key_name
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = data.aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(templatefile("${path.module}/user-data-service.sh", {
    jar_file       = "api-gateway-0.0.1-SNAPSHOT.jar"
    port           = var.container_port_gateway
    eureka_server  = "${aws_instance.eureka_server.private_ip}:${var.container_port_eureka}"
    s3_bucket      = var.jar_bucket_name
  }))

  tags = {
    Name = "${var.project_name}-api-gateway"
  }

  depends_on = [aws_instance.eureka_server, aws_instance.product_service, aws_instance.cart_service]
}

# EC2 Key Pair
resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.project_name}-ec2-key"
  public_key = tls_private_key.ec2.public_key_openssh

  tags = {
    Name = "${var.project_name}-ec2-key"
  }
}

# Save private key locally
resource "local_file" "ec2_private_key" {
  content         = tls_private_key.ec2.private_key_pem
  filename        = "${path.module}/${var.project_name}-ec2-key.pem"
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
