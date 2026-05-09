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
    security_groups = [aws_security_group.internal_alb.id]
  }

  # ALB → Cart Service
  ingress {
    from_port       = 8082
    to_port         = 8082
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id]
  }

  # ALB → API Gateway
  ingress {
    from_port       = 8089
    to_port         = 8089
    protocol        = "tcp"
    security_groups = [aws_security_group.public_alb.id]
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
    cidr_blocks = ["0.0.0.0/0"] # TEMP DEV ONLY
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

locals {
  eureka_url   = "http://${aws_instance.eureka_server.private_ip}:8761/eureka/"
  activemq_url = "tcp://${aws_instance.activemq.private_ip}:61616"
}

# EC2 Instance for Eureka Server
resource "aws_instance" "eureka_server" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.ec2_key.key_name
  subnet_id                   = aws_subnet.private[0].id
  associate_public_ip_address = false

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = templatefile("${path.module}/user-data-eureka.sh", {
    eureka_image = var.container_images.eureka
  })

  tags = {
    Name = "${var.project_name}-eureka-server"
  }

  depends_on = [aws_route_table_association.private]
}

# EC2 Instance for ActiveMQ
resource "aws_instance" "activemq" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.ec2_key.key_name
  subnet_id                   = aws_subnet.public[0].id   # public subnet → IP publique
  associate_public_ip_address = true                       # console web accessible via http://<PUBLIC_IP>:8161

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = templatefile("${path.module}/user-data-activemq.sh", {
    activemq_image = var.container_images.activemq
  })

  tags = {
    Name = "${var.project_name}-activemq"
  }

  depends_on = [aws_route_table_association.private]
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
