# Basic Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "azure_region" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "azure_secondary_region" {
  description = "Azure secondary region for DR"
  type        = string
  default     = "West US 2"
}

variable "gcp_region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-west1"
}

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "advanced-ecommerce"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

# EKS Configuration
variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.28"
}

variable "istio_version" {
  description = "Istio version"
  type        = string
  default     = "1.19.0"
}

# Application Configuration
variable "app_version" {
  description = "Application version tag"
  type        = string
  default     = "latest"
}

variable "ecr_repository_url" {
  description = "ECR repository URL for container images"
  type        = string
  default     = ""
}

# Database Configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_max_allocated_storage" {
  description = "RDS maximum allocated storage in GB for autoscaling"
  type        = number
  default     = 1000
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "ecommerce"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "read_replica_count" {
  description = "Number of read replicas to create"
  type        = number
  default     = 2
}

variable "read_replica_instance_class" {
  description = "RDS read replica instance class"
  type        = string
  default     = "db.t3.medium"
}

# Cache Configuration
variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.medium"
}

variable "cache_num_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 3
}

# Lambda Configuration
variable "lambda_zip_files" {
  description = "Map of Lambda function names to their zip file paths"
  type        = map(string)
  default = {
    user_auth       = "lambda-deployments/user-auth.zip"
    image_processor = "lambda-deployments/image-processor.zip"
    custom_metrics  = "lambda-deployments/custom-metrics.zip"
  }
}

variable "lambda_layer_zip" {
  description = "Path to Lambda layer zip file"
  type        = string
  default     = "lambda-layers/common-dependencies.zip"
}

# Security Configuration
variable "jwt_secret" {
  description = "JWT secret for token signing"
  type        = string
  sensitive   = true
}

# Optional External API Keys
variable "stripe_secret_key" {
  description = "Stripe secret key for payments"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sendgrid_api_key" {
  description = "SendGrid API key for email notifications"
  type        = string
  sensitive   = true
  default     = ""
}

variable "external_aws_access_key" {
  description = "External AWS access key for cross-account access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "external_aws_secret_key" {
  description = "External AWS secret access key"
  type        = string
  sensitive   = true
  default     = ""
}

# Monitoring Configuration
variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "argocd_admin_password" {
  description = "ArgoCD admin password"
  type        = string
  sensitive   = true
  default     = "admin"
}

# Common Tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project      = "Advanced-Ecommerce"
    Environment  = "production"
    Owner        = "CloudEngineering"
    Terraform    = "true"
    Architecture = "multi-cloud"
  }
}