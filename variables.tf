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
  default     = "ecommerce-jars-bucket"
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
  default     = 8089
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

variable "product_min_size" {
  description = "Minimum number of Product Service instances"
  type        = number
  default     = 2
}

variable "product_desired_capacity" {
  description = "Desired number of Product Service instances"
  type        = number
  default     = 2
}

variable "product_max_size" {
  description = "Maximum number of Product Service instances"
  type        = number
  default     = 4
}

variable "cart_min_size" {
  description = "Minimum number of Cart Service instances"
  type        = number
  default     = 2
}

variable "cart_desired_capacity" {
  description = "Desired number of Cart Service instances"
  type        = number
  default     = 2
}

variable "cart_max_size" {
  description = "Maximum number of Cart Service instances"
  type        = number
  default     = 4
}

variable "autoscaling_target_cpu" {
  description = "Average CPU percentage target for Product and Cart Auto Scaling"
  type        = number
  default     = 60
}

variable "autoscaling_requests_per_target" {
  description = "Average ALB requests per target used for Product and Cart request-based Auto Scaling"
  type        = number
  default     = 100
}

variable "enable_standalone_service_instances" {
  description = "Create standalone EC2 instances for API Gateway, Product and Cart instead of relying only on Auto Scaling Groups"
  type        = bool
  default     = false
}

variable "container_images" {
  description = "Container images for services (Docker Hub images used by EC2 and local runs)"
  type = object({
    api_gateway = string
    product     = string
    cart        = string
    eureka      = string
    activemq    = string
  })
  default = {
    api_gateway = "eyahaddad/api-gateway:latest"
    product     = "eyahaddad/product-service:latest"
    cart        = "eyahaddad/cart-service:latest"
    eureka      = "eyahaddad/eureka-server:latest"
    activemq    = "apache/activemq-classic:latest"
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 7
}
