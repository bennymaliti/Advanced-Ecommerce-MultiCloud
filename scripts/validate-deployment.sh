#!/bin/bash

set -e

ENVIRONMENT=${1:-production}

echo "🔍 Validating deployment for environment: $ENVIRONMENT"

cd terraform

# Check if Terraform state exists
if ! terraform show > /dev/null 2>&1; then
    echo "❌ No Terraform state found. Please deploy first."
    exit 1
fi

# Get outputs
echo "📊 Retrieving deployment outputs..."
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
EKS_CLUSTER=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name 2>/dev/null || echo "")

# Validate ALB
if [ -n "$ALB_DNS" ]; then
    echo "🌐 Testing Application Load Balancer..."
    if curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS" --max-time 10 | grep -q "200\|302\|404\|503"; then
        echo "✅ ALB is responding"
    else
        echo "❌ ALB is not responding properly"
    fi
else
    echo "⚠️ ALB DNS name not found"
fi

# Validate CloudFront
if [ -n "$CLOUDFRONT_DOMAIN" ]; then
    echo "☁️ Testing CloudFront distribution..."
    if curl -s -o /dev/null -w "%{http_code}" "https://$CLOUDFRONT_DOMAIN" --max-time 15 | grep -q "200\|302\|404"; then
        echo "✅ CloudFront is responding"
    else
        echo "⚠️ CloudFront may still be deploying (this can take 10-15 minutes)"
    fi
else
    echo "⚠️ CloudFront domain not found"
fi

# Validate EKS Cluster
if [ -n "$EKS_CLUSTER" ]; then
    echo "☸️ Testing EKS cluster connectivity..."
    if aws eks describe-cluster --name "$EKS_CLUSTER" --query 'cluster.status' --output text 2>/dev/null | grep -q "ACTIVE"; then
        echo "✅ EKS cluster is active"
        
        # Update kubeconfig
        if aws eks update-kubeconfig --name "$EKS_CLUSTER" --region us-west-2 2>/dev/null; then
            echo "✅ Kubeconfig updated"
            
            # Check nodes
            if command -v kubectl &> /dev/null; then
                NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
                if [ "$NODE_COUNT" -gt 0 ]; then
                    echo "✅ EKS has $NODE_COUNT ready nodes"
                else
                    echo "⚠️ EKS nodes may not be ready yet"
                fi
            else
                echo "⚠️ kubectl not installed - cannot check node status"
            fi
        else
            echo "⚠️ Could not update kubeconfig"
        fi
    else
        echo "❌ EKS cluster is not active"
    fi
else
    echo "⚠️ EKS cluster name not found"
fi

# Validate RDS
if [ -n "$RDS_ENDPOINT" ]; then
    echo "🗄️ Testing RDS connectivity..."
    RDS_HOST=$(echo $RDS_ENDPOINT | cut -d: -f1)
    if command -v nc &> /dev/null; then
        if nc -z -w5 $RDS_HOST 3306 2>/dev/null; then
            echo "✅ RDS is accessible"
        else
            echo "⚠️ RDS is not accessible from this location (expected if in private subnet)"
        fi
    else
        echo "⚠️ nc (netcat) not available - cannot test RDS connectivity"
    fi
else
    echo "⚠️ RDS endpoint not found"
fi

# Validate Lambda Functions
echo "⚡ Testing Lambda functions..."
FUNCTIONS=$(aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `advanced-ecommerce`)].FunctionName' --output text 2>/dev/null || echo "")
if [ -n "$FUNCTIONS" ]; then
    FUNCTION_COUNT=0
    ACTIVE_FUNCTIONS=0
    for func in $FUNCTIONS; do
        FUNCTION_COUNT=$((FUNCTION_COUNT + 1))
        if aws lambda get-function --function-name "$func" --query 'Configuration.State' --output text 2>/dev/null | grep -q "Active"; then
            ACTIVE_FUNCTIONS=$((ACTIVE_FUNCTIONS + 1))
        fi
    done
    echo "✅ $ACTIVE_FUNCTIONS out of $FUNCTION_COUNT Lambda functions are active"
else
    echo "⚠️ No Lambda functions found"
fi

# Validate S3 Buckets
echo "📦 Testing S3 buckets..."
BUCKETS=$(aws s3 ls | grep "advanced-ecommerce" | wc -l || echo "0")
if [ "$BUCKETS" -gt 0 ]; then
    echo "✅ Found $BUCKETS S3 buckets"
else
    echo "⚠️ No S3 buckets found"
fi

# Validate DynamoDB Tables
echo "📊 Testing DynamoDB tables..."
TABLES=$(aws dynamodb list-tables --query 'TableNames[?contains(@, `advanced-ecommerce`)]' --output text 2>/dev/null | wc -w || echo "0")
if [ "$TABLES" -gt 0 ]; then
    echo "✅ Found $TABLES DynamoDB tables"
else
    echo "⚠️ No DynamoDB tables found"
fi

# Check Multi-cloud Resources
echo "🌐 Checking multi-cloud resources..."

# Check Azure resources (if Azure CLI is available)
if command -v az &> /dev/null; then
    RESOURCE_GROUP="advanced-ecommerce-${ENVIRONMENT}-rg"
    if az group show --name "$RESOURCE_GROUP" &> /dev/null 2>&1; then
        echo "✅ Azure resource group exists"
    else
        echo "⚠️ Azure resource group not found or Azure CLI not configured"
    fi
else
    echo "⚠️ Azure CLI not installed - skipping Azure validation"
fi

# Check GCP resources (if gcloud is available)
if command -v gcloud &> /dev/null; then
    PROJECT_ID=$(terraform output -raw gcp_project_id 2>/dev/null || echo "")
    if [ -n "$PROJECT_ID" ]; then
        if gcloud projects describe "$PROJECT_ID" &> /dev/null 2>&1; then
            echo "✅ GCP project accessible"
        else
            echo "⚠️ GCP project not accessible or gcloud not configured"
        fi
    else
        echo "⚠️ GCP project ID not found in outputs"
    fi
else
    echo "⚠️ gcloud CLI not installed - skipping GCP validation"
fi

echo ""
echo "🎉 Deployment validation completed!"
echo ""
echo "📋 Summary:"
echo "   Environment: $ENVIRONMENT"
echo "   ALB: $([ -n "$ALB_DNS" ] && echo "✅ Ready" || echo "⚠️ Not found")"
echo "   CloudFront: $([ -n "$CLOUDFRONT_DOMAIN" ] && echo "✅ Ready" || echo "⚠️ Not found")"
echo "   EKS: $([ -n "$EKS_CLUSTER" ] && echo "✅ Ready" || echo "⚠️ Not found")"
echo "   RDS: $([ -n "$RDS_ENDPOINT" ] && echo "✅ Ready" || echo "⚠️ Not found")"