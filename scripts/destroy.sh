#!/bin/bash

set -e

ENVIRONMENT=${1:-production}
FORCE=${2:-false}

echo "💥 Destroying Advanced Multi-Cloud E-commerce Platform"
echo "📋 Environment: $ENVIRONMENT"
echo "⚠️  This will permanently delete all resources!"

if [ "$FORCE" != "true" ]; then
    echo ""
    echo "🤔 Are you absolutely sure you want to destroy the $ENVIRONMENT environment?"
    echo "This action cannot be undone. Type 'yes' to confirm:"
    read -r response
    if [[ "$response" != "yes" ]]; then
        echo "❌ Destroy cancelled"
        exit 1
    fi
fi

cd terraform

# Select workspace
echo "🏗️ Selecting workspace: $ENVIRONMENT"
terraform workspace select $ENVIRONMENT 2>/dev/null || {
    echo "❌ Workspace $ENVIRONMENT does not exist"
    exit 1
}

# Plan destroy
echo "📋 Planning destroy..."
terraform plan -destroy -var-file="environments/$ENVIRONMENT/terraform.tfvars"

if [ "$FORCE" != "true" ]; then
    echo ""
    echo "🤔 Review the destroy plan above. Continue with destruction? Type 'destroy' to confirm:"
    read -r response
    if [[ "$response" != "destroy" ]]; then
        echo "❌ Destroy cancelled"
        exit 1
    fi
fi

# Destroy resources
echo "💥 Destroying resources..."
terraform destroy -var-file="environments/$ENVIRONMENT/terraform.tfvars" -auto-approve

echo "✅ Resources destroyed successfully!"

# Clean up local files
echo "🧹 Cleaning up local files..."
rm -f terraform.tfplan
rm -f tfplan-*
rm -rf lambda-deployments/
rm -rf lambda-layers/

echo ""
echo "✅ Cleanup completed!"
echo "⚠️  Note: The S3 backend bucket and DynamoDB table were not destroyed."
echo "   If you want to remove them, run:"
echo "   aws s3 rb s3://your-terraform-state-bucket --force"
echo "   aws dynamodb delete-table --table-name terraform-state-lock-advanced"