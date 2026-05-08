

resource "aws_launch_template" "product" {
  name_prefix   = "${var.project_name}-product-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.ec2_key.key_name

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

  user_data = base64encode(templatefile("${path.module}/user-data-service.sh", {
    SERVICE_NAME = "api-gateway"
    DOCKER_IMAGE = var.container_images.api_gateway
    PORT         = var.container_port_gateway
    EUREKA_URL   = local.eureka_url
    ACTIVEMQ_URL = local.activemq_url
  }))
}

resource "aws_autoscaling_group" "product" {
  desired_capacity     = 1
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.product.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.product_service.arn]

  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "${var.project_name}-product-asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "cart" {
  desired_capacity     = 1
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.cart.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.cart_service.arn]

  health_check_type = "ELB"
}

resource "aws_autoscaling_group" "gateway" {
  desired_capacity     = 1
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.gateway.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.api_gateway.arn]

  health_check_type = "ELB"
}

resource "aws_autoscaling_policy" "product_scale_up" {
  name                   = "product-scale-up"
  scaling_adjustment     = 1 // Increase desired capacity by 1
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.product.name
}

resource "aws_autoscaling_policy" "cart_scale_up" {
  name                   = "cart-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.cart.name
}

resource "aws_autoscaling_policy" "gateway_scale_up" {
  name                   = "gateway-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.gateway.name
}