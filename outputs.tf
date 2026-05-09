output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Public entry URL routed by the Main ALB to Nginx"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ec2_eureka_server_private_ip" {
  description = "Private IP of Eureka Server EC2 instance"
  value       = aws_instance.eureka_server.private_ip
}

output "ec2_eureka_server_instance_id" {
  description = "Instance ID of Eureka Server"
  value       = aws_instance.eureka_server.id
}

output "product_alb_dns_name" {
  description = "DNS name of the public Product Service load balancer"
  value       = aws_lb.product.dns_name
}

output "product_alb_url" {
  description = "Public URL of the Product Service load balancer"
  value       = "http://${aws_lb.product.dns_name}"
}

output "cart_alb_dns_name" {
  description = "DNS name of the public Cart Service load balancer"
  value       = aws_lb.cart.dns_name
}

output "cart_alb_url" {
  description = "Public URL of the Cart Service load balancer"
  value       = "http://${aws_lb.cart.dns_name}"
}

output "nginx_gateway_asg_name" {
  description = "Name of the Nginx gateway Auto Scaling Group"
  value       = aws_autoscaling_group.nginx_gateway.name
}

output "nginx_gateway_url" {
  description = "Public URL of the Nginx gateway through the Main ALB"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ec2_key_pair_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.ec2_key.key_name
}

output "ec2_key_pair_path" {
  description = "Local path to the EC2 private key file"
  value       = local_file.ec2_private_key.filename
}

output "ec2_security_group_id" {
  description = "Security group ID for EC2 instances"
  value       = aws_security_group.ec2.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "activemq_public_ip" {
  description = "Public IP of ActiveMQ instance"
  value       = aws_instance.activemq.public_ip
}

output "activemq_console_url" {
  description = "ActiveMQ Web Console URL (admin/admin)"
  value       = "http://${aws_instance.activemq.public_ip}:8161"
}
