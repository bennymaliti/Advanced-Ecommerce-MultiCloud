#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔧 Creating Lambda deployment packages..."

# Create directories
mkdir -p lambda-deployments
mkdir -p lambda-layers

# User Authentication Lambda
echo "📦 Packaging user authentication Lambda..."
cd lambda-functions/user-auth
zip -r ../../lambda-deployments/user-auth.zip . -x "*.pyc" "__pycache__/*"
cd "$PROJECT_ROOT"

# Image Processing Lambda
echo "📦 Packaging image processing Lambda..."
cd lambda-functions/image-processor
zip -r ../../lambda-deployments/image-processor.zip . -x "*.pyc" "__pycache__/*"
cd "$PROJECT_ROOT"

# Custom Metrics Lambda
echo "📦 Packaging custom metrics Lambda..."
cd lambda-functions/custom-metrics
zip -r ../../lambda-deployments/custom-metrics.zip . -x "*.pyc" "__pycache__/*"
cd "$PROJECT_ROOT"

# Create Lambda Layer for common dependencies
echo "📦 Creating Lambda layer for common dependencies..."
mkdir -p lambda-layers/python/lib/python3.9/site-packages

# Install common dependencies
pip install -t lambda-layers/python/lib/python3.9/site-packages \
  requests \
  boto3 \
  pillow \
  pyjwt \
  redis

cd lambda-layers
zip -r ../lambda-layers/common-dependencies.zip . -x "*.pyc" "__pycache__/*"
cd "$PROJECT_ROOT"

# Cleanup temporary directories
rm -rf lambda-layers/python

echo "✅ Lambda packages created successfully!"
echo "📂 Packages location:"
echo "   - lambda-deployments/"
echo "   - lambda-layers/"