# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb-1"
  }
}

resource "aws_lb" "product" {
  name               = "${var.project_name}-product-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name    = "${var.project_name}-product-alb"
    Service = "product-service"
  }
}

resource "aws_lb" "cart" {
  name               = "${var.project_name}-cart-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name    = "${var.project_name}-cart-alb"
    Service = "cart-service"
  }
}

# Target Group for API Gateway Service
resource "aws_lb_target_group" "api_gateway" {
  name        = "${var.project_name}-api-gateway-tg-1"
  port        = 8089
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    matcher             = "200-499"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15
  }

  tags = {
    Name = "${var.project_name}-api-gateway-tg-1"
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

resource "aws_lb_listener" "product" {
  load_balancer_arn = aws_lb.product.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product_service.arn
  }
}

resource "aws_lb_listener" "cart" {
  load_balancer_arn = aws_lb.cart.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cart_service.arn
  }
}

# Target Group for Product Service (internal routing)
resource "aws_lb_target_group" "product_service" {
  name        = "${var.project_name}-product-service-tg-1"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    matcher             = "200-499"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15
  }

  tags = {
    Name = "${var.project_name}-product-service-tg-1"
  }
}

# Target Group for Cart Service (internal routing)
resource "aws_lb_target_group" "cart_service" {
  name        = "${var.project_name}-cart-service-tg-1"
  port        = 8082
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    matcher             = "200-499"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15
  }

  tags = {
    Name = "${var.project_name}-cart-service-tg-1"
  }
}


resource "aws_lb_target_group_attachment" "api_gateway" {
  target_group_arn = aws_lb_target_group.api_gateway.arn
  target_id        = aws_instance.api_gateway.id
  port             = var.container_port_gateway
}

