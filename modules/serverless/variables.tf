variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}

variable "lambda_zip_files" {
  description = "Map of Lambda function names to their zip file paths"
  type        = map(string)
  default = {
    user_auth        = "lambda-deployments/user-auth.zip"
    image_processor  = "lambda-deployments/image-processor.zip"
    custom_metrics   = "lambda-deployments/custom-metrics.zip"
  }
}

variable "lambda_layer_zip" {
  description = "Path to Lambda layer zip file"
  type        = string
  default     = "lambda-layers/common-dependencies.zip"
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  type        = string
}

variable "jwt_secret" {
  description = "JWT secret for token signing"
  type        = string
  sensitive   = true
}

variable "s3_bucket_name" {
  description = "S3 bucket name for image processing"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for metadata storage"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}