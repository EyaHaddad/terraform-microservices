output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Full URL of the API Gateway via load balancer"
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

output "ec2_product_service_private_ip" {
  description = "Private IP of Product Service EC2 instance"
  value       = aws_instance.product_service.private_ip
}

output "ec2_product_service_instance_id" {
  description = "Instance ID of Product Service"
  value       = aws_instance.product_service.id
}

output "ec2_cart_service_private_ip" {
  description = "Private IP of Cart Service EC2 instance"
  value       = aws_instance.cart_service.private_ip
}

output "ec2_cart_service_instance_id" {
  description = "Instance ID of Cart Service"
  value       = aws_instance.cart_service.id
}

output "ec2_api_gateway_private_ip" {
  description = "Private IP of API Gateway EC2 instance"
  value       = aws_instance.api_gateway.private_ip
}

output "ec2_api_gateway_instance_id" {
  description = "Instance ID of API Gateway"
  value       = aws_instance.api_gateway.id
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
