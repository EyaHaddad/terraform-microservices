

resource "aws_launch_template" "product" {
  name_prefix   = "${var.project_name}-product-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.ec2_key.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "${var.project_name}-product"
      Service = "product-service"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name    = "${var.project_name}-product-volume"
      Service = "product-service"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user-data-service.sh", {
    SERVICE_NAME        = "product-service"
    DOCKER_IMAGE        = var.container_images.product
    PORT                = var.container_port_product
    EUREKA_URL          = local.eureka_url
    ACTIVEMQ_URL        = local.activemq_url
    PRODUCT_SERVICE_URL = ""
    CART_SERVICE_URL    = ""
  }))
}

resource "aws_launch_template" "cart" {
  name_prefix   = "${var.project_name}-cart-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.ec2_key.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "${var.project_name}-cart"
      Service = "cart-service"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name    = "${var.project_name}-cart-volume"
      Service = "cart-service"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user-data-service.sh", {
    SERVICE_NAME        = "cart-service"
    DOCKER_IMAGE        = var.container_images.cart
    PORT                = var.container_port_cart
    EUREKA_URL          = local.eureka_url
    ACTIVEMQ_URL        = local.activemq_url
    PRODUCT_SERVICE_URL = ""
    CART_SERVICE_URL    = ""
  }))
}

resource "aws_launch_template" "nginx_gateway" {
  name_prefix   = "${var.project_name}-nginx-gateway-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.ec2_key.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "${var.project_name}-nginx-gateway"
      Service = "nginx-gateway"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name    = "${var.project_name}-nginx-gateway-volume"
      Service = "nginx-gateway"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user-data-nginx-gateway.sh", {
    PRODUCT_SERVICE_URL = "http://${aws_lb.product.dns_name}"
    CART_SERVICE_URL    = "http://${aws_lb.cart.dns_name}"
  }))
}

resource "aws_autoscaling_group" "product" {
  desired_capacity    = var.product_desired_capacity
  max_size            = var.product_max_size
  min_size            = var.product_min_size
  vpc_zone_identifier = aws_subnet.private[*].id

  launch_template {
    id      = aws_launch_template.product.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.product_service.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 600
  depends_on                = [aws_route_table_association.private, aws_instance.eureka_server, aws_instance.activemq]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-product"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "cart" {
  desired_capacity    = var.cart_desired_capacity
  max_size            = var.cart_max_size
  min_size            = var.cart_min_size
  vpc_zone_identifier = aws_subnet.private[*].id

  launch_template {
    id      = aws_launch_template.cart.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.cart_service.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 600
  depends_on                = [aws_route_table_association.private, aws_instance.eureka_server, aws_instance.activemq]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-cart"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "nginx_gateway" {
  desired_capacity    = var.nginx_desired_capacity
  max_size            = var.nginx_max_size
  min_size            = var.nginx_min_size
  vpc_zone_identifier = aws_subnet.private[*].id

  launch_template {
    id      = aws_launch_template.nginx_gateway.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.nginx_gateway.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 180
  depends_on                = [aws_route_table_association.private, aws_lb_listener.product, aws_lb_listener.cart]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-nginx-gateway"
    propagate_at_launch = true
  }
}

# Autoscaling policies for product and cart services based on CPU utilization and request count per target
resource "aws_autoscaling_policy" "product_request_tracking" {
  name                   = "${var.project_name}-product-requests-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.product.name

  target_tracking_configuration {
    target_value = var.autoscaling_requests_per_target

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.product.arn_suffix}/${aws_lb_target_group.product_service.arn_suffix}"
    }
  }
}

resource "aws_autoscaling_policy" "nginx_cpu_tracking" {
  name                   = "${var.project_name}-nginx-cpu-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.nginx_gateway.name

  target_tracking_configuration {
    target_value = var.autoscaling_target_cpu

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

resource "aws_autoscaling_policy" "product_cpu_tracking" {
  name                   = "${var.project_name}-product-cpu-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.product.name

  target_tracking_configuration {
    target_value = var.autoscaling_target_cpu

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

resource "aws_autoscaling_policy" "cart_request_tracking" {
  name                   = "${var.project_name}-cart-requests-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.cart.name

  target_tracking_configuration {
    target_value = var.autoscaling_requests_per_target

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.cart.arn_suffix}/${aws_lb_target_group.cart_service.arn_suffix}"
    }
  }
}

resource "aws_autoscaling_policy" "cart_cpu_tracking" {
  name                   = "${var.project_name}-cart-cpu-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.cart.name

  target_tracking_configuration {
    target_value = var.autoscaling_target_cpu

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
