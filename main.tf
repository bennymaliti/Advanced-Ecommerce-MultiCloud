# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Authentication token for EKS (used by Helm provider)
data "aws_eks_cluster_auth" "eks" {
  name = module.eks_cluster.cluster_name
}

#============================================
# CORE INFRASTRUCTURE MODULES
#============================================

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr             = var.vpc_cidr
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  project_name         = var.project_name
  
  tags = var.common_tags
}

# Security Module
module "security" {
  source = "./modules/security"
  
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = module.vpc.vpc_cidr_block
  project_name = var.project_name
  
  tags = var.common_tags
}

# Storage Module
module "storage" {
  source = "./modules/storage"
  
  project_name = var.project_name
  environment  = var.environment
  
  tags = var.common_tags
}

# Database Module
module "database" {
  source = "./modules/database"
  
  project_name               = var.project_name
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  database_security_group_id = module.security.database_sg_id
  
  db_instance_class         = var.db_instance_class
  db_allocated_storage      = var.db_allocated_storage
  db_max_allocated_storage  = var.db_max_allocated_storage
  db_name                   = var.db_name
  db_username               = var.db_username
  db_password               = var.db_password
  read_replica_count        = var.read_replica_count
  read_replica_instance_class = var.read_replica_instance_class
  
  tags = var.common_tags
}

# Cache Module
# SNS topic for cache notifications (required by cache module)
resource "aws_sns_topic" "cache_notifications" {
  name = "${var.project_name}-cache-notifications"
  tags = var.common_tags
}

module "cache" {
  source = "./modules/cache"
  
  project_name               = var.project_name
  private_subnet_ids         = module.vpc.private_subnet_ids
  elasticache_security_group_id = module.security.cache_sg_id
  num_cache_nodes            = var.cache_num_nodes
  sns_topic_arn              = aws_sns_topic.cache_notifications.arn
}

# Cognito Module
module "cognito" {
  source = "./modules/cognito"
  
  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name
  
  tags = var.common_tags
}

# Secrets Module
module "secrets" {
  source = "./modules/secrets"
  
  project_name   = var.project_name
  environment    = var.environment
  db_password    = var.db_password
  db_username    = var.db_username
  db_endpoint    = module.database.rds_endpoint
  db_name        = var.db_name
  redis_endpoint = module.cache.redis_endpoint
  jwt_secret     = var.jwt_secret
  
  # Optional external API keys
  stripe_secret_key        = var.stripe_secret_key
  sendgrid_api_key        = var.sendgrid_api_key
  external_aws_access_key = var.external_aws_access_key
  external_aws_secret_key = var.external_aws_secret_key
  
  tags = var.common_tags
}

# Compute Module

# SNS topic for compute notifications (required by compute module)
resource "aws_sns_topic" "compute_notifications" {
  name = "${var.project_name}-compute-notifications"
  tags = var.common_tags
}

module "compute" {
  source = "./modules/compute"
  
  project_name            = var.project_name
  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  private_subnet_ids      = module.vpc.private_subnet_ids
  alb_security_group_id   = module.security.alb_sg_id
  ec2_security_group_id   = module.security.ec2_sg_id
  sns_topic_arn           = aws_sns_topic.compute_notifications.arn
}

# EKS Module
module "eks_cluster" {
  source = "./modules/eks"
  
  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.eks_cluster_version
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # Node Groups Configuration
  node_groups = {
    web_tier = {
      instance_types = ["t3.medium"]
      scaling_config = {
        desired_size = 3
        max_size     = 10
        min_size     = 2
      }
      labels = {
        tier        = "web"
        environment = var.environment
      }
      taints = []
    }
    
    app_tier = {
      instance_types = ["c5.large"]
      scaling_config = {
        desired_size = 6
        max_size     = 20
        min_size     = 3
      }
      labels = {
        tier        = "application"
        environment = var.environment
      }
      taints = []
    }
    
    worker_tier = {
      instance_types = ["r5.xlarge"]
      scaling_config = {
        desired_size = 2
        max_size     = 8
        min_size     = 1
      }
      labels = {
        tier        = "worker"
        environment = var.environment
      }
      taints = [
        {
          key    = "workload"
          value  = "batch"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
  
  # Cluster Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
  
  tags = var.common_tags
}

# Serverless Module
module "serverless" {
  source = "./modules/serverless"
  
  project_name               = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  private_subnet_ids        = module.vpc.private_subnet_ids
  lambda_security_group_id  = module.security.lambda_sg_id
  cognito_user_pool_id     = module.cognito.user_pool_id
  cognito_client_id        = module.cognito.client_id
  jwt_secret               = var.jwt_secret
  s3_bucket_name          = module.storage.assets_bucket_name
  dynamodb_table_name     = module.storage.image_metadata_table_name
  
  lambda_zip_files = var.lambda_zip_files
  lambda_layer_zip = var.lambda_layer_zip
  
  tags = var.common_tags
  
  depends_on = [
    module.vpc,
    module.security,
    module.storage,
    module.cognito
  ]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name        = var.project_name
  aws_region         = var.aws_region
}

#============================================
# KUBERNETES PROVIDER CONFIGURATION
#============================================

provider "kubernetes" {
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  host                   = module.eks_cluster.cluster_endpoint

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name]
  }
}

provider "helm" {
  # Using default kubeconfig / environment (KUBECONFIG) instead of an inline kubernetes block to avoid the unexpected block error.
  # Ensure your kubeconfig points at the EKS cluster before running terraform apply:
  # aws eks update-kubeconfig --name ${module.eks_cluster.cluster_name} --region ${var.aws_region}
}

#============================================
# API GATEWAY CONFIGURATION
#============================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "Advanced E-commerce API Gateway"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = var.common_tags
}

# Authentication Resource
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_integration" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_post.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = module.serverless.user_auth_lambda_arn
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  
  depends_on = [
    aws_api_gateway_method.auth_post,
    aws_api_gateway_integration.auth_integration
  ]
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.auth.id,
      aws_api_gateway_method.auth_post.id,
      aws_api_gateway_integration.auth_integration.id,
    ]))
  }
}

resource "aws_api_gateway_stage" "main" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  deployment_id = aws_api_gateway_deployment.main.id
  stage_name    = var.environment
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.serverless.user_auth_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

#============================================
# CLOUDFRONT DISTRIBUTION
#============================================

resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = module.compute.alb_dns_name
    origin_id   = "ALB-${var.project_name}"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ALB-${var.project_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    
    forwarded_values {
      query_string = false
      headers      = ["Host"]
      
      cookies {
        forward = "none"
      }
    }
    
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }
  
  # Cache behavior for static assets
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ALB-${var.project_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    
    forwarded_values {
      query_string = false
      
      cookies {
        forward = "none"
      }
    }
    
    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }
  
  price_class = "PriceClass_100"
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.common_tags
}

#============================================
# MULTI-CLOUD RESOURCES
#============================================

# Azure Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.azure_region
  
  tags = merge(var.common_tags, {
    Platform = "Azure"
  })
}

# Azure Service Bus
resource "azurerm_servicebus_namespace" "main" {
  name                = "${var.project_name}-${var.environment}-sb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Premium"
  capacity            = 1
  
  tags = merge(var.common_tags, {
    Platform = "Azure"
  })
}

resource "azurerm_servicebus_queue" "order_processing" {
  name         = "order-processing-queue"
  namespace_id = azurerm_servicebus_namespace.main.id
  
  max_size_in_megabytes = 5120
}

# Azure Cosmos DB
resource "azurerm_cosmosdb_account" "main" {
  name                = "${var.project_name}-${var.environment}-cosmos"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  
  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }
  
  geo_location {
    location          = var.azure_region
    failover_priority = 0
  }
  
  geo_location {
    location          = var.azure_secondary_region
    failover_priority = 1
  }
  
  tags = merge(var.common_tags, {
    Platform = "Azure"
  })
}

resource "azurerm_cosmosdb_sql_database" "ecommerce" {
  name                = "ecommerce-db"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
}

# GCP BigQuery Dataset
resource "google_bigquery_dataset" "ecommerce_analytics" {
  dataset_id    = "ecommerce_analytics"
  friendly_name = "E-commerce Analytics"
  description   = "Analytics dataset for multi-cloud e-commerce platform"
  location      = "US"
  
  default_table_expiration_ms = 3600000
  
  labels = {
    environment = var.environment
    project     = var.project_name
  }
}

# BigQuery Tables
resource "google_bigquery_table" "user_events" {
  dataset_id = google_bigquery_dataset.ecommerce_analytics.dataset_id
  table_id   = "user_events"
  
  schema = jsonencode([
    {
      name = "user_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "event_type"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "timestamp"
      type = "TIMESTAMP"
      mode = "REQUIRED"
    },
    {
      name = "properties"
      type = "JSON"
      mode = "NULLABLE"
    }
  ])
  
  labels = {
    environment = var.environment
    project     = var.project_name
  }
}

# GCP Pub/Sub Topic
resource "google_pubsub_topic" "user_events" {
  name = "${var.project_name}-user-events"
  
  labels = {
    environment = var.environment
    project     = var.project_name
  }
}