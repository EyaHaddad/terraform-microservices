variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecommerce"
}

variable "jar_bucket_name" {
  description = "Name of the S3 bucket used to store application JARs"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "container_port_gateway" {
  description = "Container port for API Gateway"
  type        = number
  default     = 8080
}

variable "container_port_product" {
  description = "Container port for Product Service"
  type        = number
  default     = 8081
}

variable "container_port_cart" {
  description = "Container port for Cart Service"
  type        = number
  default     = 8082
}

variable "container_port_eureka" {
  description = "Container port for Eureka Server"
  type        = number
  default     = 8761
}

variable "container_port_activemq" {
  description = "Container port for ActiveMQ"
  type        = number
  default     = 61616
}

variable "ecs_task_cpu" {
  description = "ECS task CPU units (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "ECS task memory in MB (512, 1024, 2048, 4096, 8192)"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired number of tasks for each service"
  type        = number
  default     = 1
}

variable "container_images" {
  description = "Container images for services (will be updated with ECR URIs)"
  type = object({
    api_gateway = string
    product     = string
    cart        = string
    eureka      = string
    activemq    = string
  })
  default = {
    api_gateway = "ecommerce/api-gateway:latest"
    product     = "ecommerce/product-service:latest"
    cart        = "ecommerce/cart-service:latest"
    eureka      = "ecommerce/eureka-server:latest"
    activemq    = "apache/activemq-classic:latest"
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 7
}
