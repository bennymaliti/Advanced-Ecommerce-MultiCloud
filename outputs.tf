# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# EKS Outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks_cluster.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks_cluster.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks_cluster.cluster_arn
}

output "kubeconfig_update_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_name}"
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.compute.alb_zone_id
}

# Database Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.rds_endpoint
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.database.rds_port
}

output "read_replica_endpoints" {
  description = "Read replica endpoints"
  value       = module.database.read_replica_endpoints
}

# Cache Outputs
output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.cache.redis_endpoint
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = module.cache.redis_reader_endpoint
}

# Storage Outputs
output "assets_bucket_name" {
  description = "Name of the assets S3 bucket"
  value       = module.storage.assets_bucket_name
}

output "logs_bucket_name" {
  description = "Name of the logs S3 bucket"
  value       = module.storage.logs_bucket_name
}

output "image_metadata_table_name" {
  description = "Name of the image metadata DynamoDB table"
  value       = module.storage.image_metadata_table_name
}

# ECR Outputs
output "ecr_web_repository_url" {
  description = "URL of the web app ECR repository"
  value       = module.compute.ecr_web_repository_url
}

output "ecr_api_repository_url" {
  description = "URL of the API ECR repository"
  value       = module.compute.ecr_api_repository_url
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "ID of the Cognito user pool client"
  value       = module.cognito.client_id
}

output "cognito_domain" {
  description = "Cognito user pool domain"
  value       = module.cognito.domain
}

# Serverless Outputs
output "user_auth_lambda_arn" {
  description = "ARN of the user authentication Lambda function"
  value       = module.serverless.user_auth_lambda_arn
}

output "image_processor_lambda_arn" {
  description = "ARN of the image processor Lambda function"
  value       = module.serverless.image_processor_lambda_arn
}

# API Gateway Outputs
output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.main.id
}

# CloudFront Outputs
output "cloudfront_domain_name" {
  description = "Domain name of CloudFront distribution"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of CloudFront distribution"
  value       = aws_cloudfront_distribution.main.id
}

# Monitoring Outputs
output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.monitoring.cloudwatch_dashboard_url
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = module.monitoring.sns_topic_arn
}

# Secrets Outputs
output "db_password_secret_arn" {
  description = "ARN of the database password secret"
  value       = module.secrets.db_password_secret_arn
}

output "jwt_secret_arn" {
  description = "ARN of the JWT secret"
  value       = module.secrets.jwt_secret_arn
}

# Multi-Cloud Outputs
output "azure_resource_group_name" {
  description = "Name of the Azure resource group"
  value       = azurerm_resource_group.main.name
}

output "azure_cosmos_endpoint" {
  description = "Azure Cosmos DB endpoint"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "azure_servicebus_namespace" {
  description = "Azure Service Bus namespace"
  value       = azurerm_servicebus_namespace.main.name
}

output "gcp_bigquery_dataset" {
  description = "GCP BigQuery dataset ID"
  value       = google_bigquery_dataset.ecommerce_analytics.dataset_id
}

output "gcp_pubsub_topic" {
  description = "GCP Pub/Sub topic name"
  value       = google_pubsub_topic.user_events.name
}

# Application URLs
output "application_urls" {
  description = "Application access URLs"
  value = {
    alb_direct        = "http://${module.compute.alb_dns_name}"
    cloudfront        = "https://${aws_cloudfront_distribution.main.domain_name}"
    api_gateway       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
    cognito_hosted_ui = "https://${module.cognito.domain}.auth.${var.aws_region}.amazoncognito.com/login"
  }
}

# Important Configuration Information
output "deployment_info" {
  description = "Important deployment information"
  value = {
    environment  = var.environment
    aws_region   = var.aws_region
    azure_region = var.azure_region
    gcp_region   = var.gcp_region
    cluster_name = module.eks_cluster.cluster_name
    domain_name  = var.domain_name
  }
}

# Cost Optimization Information
output "cost_optimization_info" {
  description = "Cost optimization recommendations"
  value = {
    recommendation    = "Consider using Reserved Instances for predictable workloads"
    spot_instances    = "Use spot instances for non-critical worker nodes"
    scheduled_scaling = "Implement scheduled scaling for non-production environments"
    resource_tagging  = "All resources are tagged for cost allocation"
  }
}

# Security Information
output "security_info" {
  description = "Security configuration information"
  value = {
    encryption_at_rest    = "Enabled for RDS, ElastiCache, S3, and DynamoDB"
    encryption_in_transit = "Enabled for all services"
    secrets_management    = "AWS Secrets Manager integrated"
    network_security      = "VPC with private subnets and security groups"
    authentication        = "Cognito user pool configured"
    api_security          = "JWT token-based authentication"
  }
}

# Monitoring Information
output "monitoring_info" {
  description = "Monitoring and observability information"
  value = {
    distributed_tracing = "X-Ray enabled for Lambda functions"
    custom_metrics      = "Custom CloudWatch metrics published every 5 minutes"
    log_aggregation     = "CloudWatch Logs with retention policies"
    alerting            = "SNS notifications for critical alerts"
    dashboards          = "CloudWatch dashboard created"
  }
}

# Multi-Cloud Architecture Information
output "multi_cloud_info" {
  description = "Multi-cloud architecture information"
  value = {
    aws_services   = "EKS, Lambda, RDS, ElastiCache, S3, CloudFront, API Gateway, Cognito"
    azure_services = "Service Bus, Cosmos DB, Resource Groups"
    gcp_services   = "BigQuery, Pub/Sub, Cloud Functions (planned)"
    data_flow      = "AWS → Azure (messaging) → GCP (analytics)"
    benefits       = "Vendor diversification, cost optimization, best-of-breed services"
  }
}

# Next Steps
output "next_steps" {
  description = "Recommended next steps after deployment"
  value = {
    step_1 = "Update kubeconfig: ${local.kubeconfig_command}"
    step_2 = "Configure DNS records for ${var.domain_name}"
    step_3 = "Deploy applications to EKS cluster"
    step_4 = "Set up SSL certificates"
    step_5 = "Configure monitoring dashboards"
    step_6 = "Run load tests to validate auto-scaling"
    step_7 = "Implement backup and disaster recovery procedures"
  }
}

# Local values for computed outputs
locals {
  kubeconfig_command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_name}"
}