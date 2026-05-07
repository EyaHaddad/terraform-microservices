# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for API Gateway Service
resource "aws_lb_target_group" "api_gateway" {
  name        = "${var.project_name}-api-gateway-tg"
  port        = var.container_port_gateway
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/actuator/health"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-api-gateway-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}

# Target Group for Product Service (internal routing)
resource "aws_lb_target_group" "product_service" {
  name        = "${var.project_name}-product-service-tg"
  port        = var.container_port_product
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/actuator/health"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-product-service-tg"
  }
}

# Target Group for Cart Service (internal routing)
resource "aws_lb_target_group" "cart_service" {
  name        = "${var.project_name}-cart-service-tg"
  port        = var.container_port_cart
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/actuator/health"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-cart-service-tg"
  }
}

# Target Group for Eureka Server (internal routing)
resource "aws_lb_target_group" "eureka_server" {
  name        = "${var.project_name}-eureka-server-tg"
  port        = var.container_port_eureka
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-eureka-server-tg"
  }
}

# Register API Gateway instance with ALB
resource "aws_lb_target_group_attachment" "api_gateway" {
  target_group_arn = aws_lb_target_group.api_gateway.arn
  target_id        = aws_instance.api_gateway.id
  port             = var.container_port_gateway
}

# Register Product Service instance with ALB
resource "aws_lb_target_group_attachment" "product_service" {
  target_group_arn = aws_lb_target_group.product_service.arn
  target_id        = aws_instance.product_service.id
  port             = var.container_port_product
}

# Register Cart Service instance with ALB
resource "aws_lb_target_group_attachment" "cart_service" {
  target_group_arn = aws_lb_target_group.cart_service.arn
  target_id        = aws_instance.cart_service.id
  port             = var.container_port_cart
}

# Register Eureka Server instance with ALB
resource "aws_lb_target_group_attachment" "eureka_server" {
  target_group_arn = aws_lb_target_group.eureka_server.arn
  target_id        = aws_instance.eureka_server.id
  port             = var.container_port_eureka
}

# Add listener for Product Service
resource "aws_lb_listener" "product_service" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.container_port_product
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product_service.arn
  }
}

# Add listener for Cart Service
resource "aws_lb_listener" "cart_service" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.container_port_cart
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cart_service.arn
  }
}

# Add listener for Eureka Server
resource "aws_lb_listener" "eureka_server" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.container_port_eureka
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eureka_server.arn
  }
}
