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


resource "aws_lb_listener_rule" "product" {
  listener_arn = aws_lb_listener.main.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product_service.arn
  }

  condition {
    path_pattern {
      values = ["/api/products*"]
    }
  }
}

resource "aws_lb_listener_rule" "cart" {
  listener_arn = aws_lb_listener.main.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cart_service.arn
  }

  condition {
    path_pattern {
      values = ["/api/cart*"]
    }
  }
}

resource "aws_lb_target_group_attachment" "api_gateway" {
  count            = var.enable_standalone_service_instances ? 1 : 0
  target_group_arn = aws_lb_target_group.api_gateway.arn
  target_id        = aws_instance.api_gateway[0].id
  port             = var.container_port_gateway
}

resource "aws_lb_target_group_attachment" "product_service" {
  count            = var.enable_standalone_service_instances ? 1 : 0
  target_group_arn = aws_lb_target_group.product_service.arn
  target_id        = aws_instance.product_service[0].id
  port             = var.container_port_product
}

resource "aws_lb_target_group_attachment" "cart_service" {
  count            = var.enable_standalone_service_instances ? 1 : 0
  target_group_arn = aws_lb_target_group.cart_service.arn
  target_id        = aws_instance.cart_service[0].id
  port             = var.container_port_cart
}
