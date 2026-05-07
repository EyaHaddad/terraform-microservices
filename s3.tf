# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Outputs
output "s3_jar_bucket_name" {
  value       = var.jar_bucket_name
  description = "S3 bucket name for JAR files"
}

output "s3_jar_bucket_arn" {
  value       = "arn:aws:s3:::${var.jar_bucket_name}"
  description = "S3 bucket ARN for JAR files"
}

output "aws_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS Account ID"
}
