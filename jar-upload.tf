# Upload JAR files to S3 bucket
# JAR files are expected to be in the target directories of each service

# Eureka Server JAR
resource "aws_s3_object" "eureka_jar" {
  bucket = var.jar_bucket_name
  key    = "eureka-server-0.0.1-SNAPSHOT.jar"
  source = "${path.module}/../eureka-server/target/eureka-server-0.0.1-SNAPSHOT.jar.original"
  etag   = filemd5("${path.module}/../eureka-server/target/eureka-server-0.0.1-SNAPSHOT.jar.original")
}

# Product Service JAR
resource "aws_s3_object" "product_jar" {
  bucket = var.jar_bucket_name
  key    = "product-service-0.0.1-SNAPSHOT.jar"
  source = "${path.module}/../product-service/target/product-service-0.0.1-SNAPSHOT.jar.original"
  etag   = filemd5("${path.module}/../product-service/target/product-service-0.0.1-SNAPSHOT.jar.original")
}

# Cart Service JAR
resource "aws_s3_object" "cart_jar" {
  bucket = var.jar_bucket_name
  key    = "cart-service-0.0.1-SNAPSHOT.jar"
  source = "${path.module}/../cart-service/target/cart-service-0.0.1-SNAPSHOT.jar.original"
  etag   = filemd5("${path.module}/../cart-service/target/cart-service-0.0.1-SNAPSHOT.jar.original")
}

# API Gateway JAR
resource "aws_s3_object" "api_gateway_jar" {
  bucket = var.jar_bucket_name
  key    = "api-gateway-0.0.1-SNAPSHOT.jar"
  source = "${path.module}/../api-gateway/target/api-gateway-0.0.1-SNAPSHOT.jar.original"
  etag   = filemd5("${path.module}/../api-gateway/target/api-gateway-0.0.1-SNAPSHOT.jar.original")
}
