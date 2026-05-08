

resource "aws_launch_template" "product" {
  name_prefix   = "${var.project_name}-product-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.ec2_key.key_name

  network_interfaces {
    associate_public_ip_address = true
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
    SERVICE_NAME = "product-service"
    DOCKER_IMAGE = var.container_images.product
    PORT         = var.container_port_product
    EUREKA_URL   = local.eureka_url
    ACTIVEMQ_URL = local.activemq_url
  }))
}

resource "aws_launch_template" "cart" {
  name_prefix   = "${var.project_name}-cart-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.ec2_key.key_name

  network_interfaces {
    associate_public_ip_address = true
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
    SERVICE_NAME = "cart-service"
    DOCKER_IMAGE = var.container_images.cart
    PORT         = var.container_port_cart
    EUREKA_URL   = local.eureka_url
    ACTIVEMQ_URL = local.activemq_url
  }))
}

resource "aws_launch_template" "gateway" {
  name_prefix   = "${var.project_name}-gateway-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.ec2_key.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "${var.project_name}-api-gateway"
      Service = "api-gateway"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name    = "${var.project_name}-api-gateway-volume"
      Service = "api-gateway"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user-data-service.sh", {
    SERVICE_NAME = "api-gateway"
    DOCKER_IMAGE = var.container_images.api_gateway
    PORT         = var.container_port_gateway
    EUREKA_URL   = local.eureka_url
    ACTIVEMQ_URL = local.activemq_url
  }))
}

resource "aws_autoscaling_group" "product" {
  desired_capacity    = var.product_desired_capacity
  max_size            = var.product_max_size
  min_size            = var.product_min_size
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.product.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.product_service.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300
  depends_on                = [aws_instance.eureka_server, aws_instance.activemq]

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
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.cart.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.cart_service.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300
  depends_on                = [aws_instance.eureka_server, aws_instance.activemq]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-cart"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "gateway" {
  desired_capacity    = var.desired_count
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.gateway.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.api_gateway.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300
  depends_on                = [aws_instance.eureka_server, aws_instance.activemq]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-api-gateway"
    propagate_at_launch = true
  }
}

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

resource "aws_autoscaling_policy" "gateway_scale_up" {
  name                   = "gateway-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.gateway.name
}
