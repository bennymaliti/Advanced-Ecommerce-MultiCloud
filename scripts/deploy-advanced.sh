#!/bin/bash

set -e

ENVIRONMENT=${1:-production}
SKIP_PLAN=${2:-false}

echo "🚀 Deploying Advanced Multi-Cloud E-commerce Platform"
echo "📋 Environment: $ENVIRONMENT"
echo "📋 Skip Plan: $SKIP_PLAN"

# Check dependencies
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI is required but not installed."; exit 1; }

# Verify AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS credentials not configured or expired"
    exit 1
fi

# Create Lambda packages
echo "📦 Creating Lambda deployment packages..."
./scripts/create-lambda-packages.sh

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init -upgrade

# Select workspace
echo "🏗️ Selecting workspace: $ENVIRONMENT"
terraform workspace select $ENVIRONMENT || terraform workspace new $ENVIRONMENT

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
if [ "$SKIP_PLAN" != "true" ]; then
    echo "📋 Planning deployment..."
    terraform plan -var-file="environments/$ENVIRONMENT/terraform.tfvars" -out=tfplan-$ENVIRONMENT
    
    echo "🤔 Review the plan above. Continue with deployment? (y/n)"
    read -r response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        echo "❌ Deployment cancelled"
        exit 1
    fi
    
    # Apply with plan file
    echo "🚀 Applying Terraform configuration..."
    terraform apply tfplan-$ENVIRONMENT
    
    # Cleanup plan file
    rm -f tfplan-$ENVIRONMENT
else
    # Apply directly
    echo "🚀 Applying Terraform configuration..."
    terraform apply -var-file="environments/$ENVIRONMENT/terraform.tfvars" -auto-approve
fi

echo "✅ Deployment completed successfully!"

# Display important outputs
echo ""
echo "📊 Important URLs and Information:"
terraform output -json | jq -r '
  .application_urls.value | 
  to_entries[] | 
  "🌐 \(.key | ascii_upcase): \(.value)"
'

echo ""
echo "🔍 Next steps:"
echo "  1. Configure DNS records for your domain"
echo "  2. Set up SSL certificates"
echo "  3. Configure application secrets in AWS Secrets Manager"
echo "  4. Deploy your application containers to EKS"
echo "  5. Run load tests to validate auto-scaling"