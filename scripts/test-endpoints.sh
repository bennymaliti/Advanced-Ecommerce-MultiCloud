#!/bin/bash

set -e

ENVIRONMENT=${1:-production}

echo "🧪 Testing application endpoints for environment: $ENVIRONMENT"

cd terraform

# Get outputs
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name 2>/dev/null || echo "")
USER_AUTH_URL=$(terraform output -raw user_auth_function_url 2>/dev/null || echo "")

echo "📊 Testing endpoints..."

# Test ALB
if [ -n "$ALB_DNS" ]; then
    echo "🌐 Testing ALB (http://$ALB_DNS)..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS" --max-time 10 || echo "000")
    case $RESPONSE in
        200|301|302|404) echo "✅ ALB responding (HTTP $RESPONSE)" ;;
        503) echo "⚠️ ALB responding but no healthy targets (HTTP $RESPONSE)" ;;
        000) echo "❌ ALB not responding (timeout)" ;;
        *) echo "⚠️ ALB responding with HTTP $RESPONSE" ;;
    esac
else
    echo "⚠️ ALB DNS not found"
fi

# Test CloudFront
if [ -n "$CLOUDFRONT_DOMAIN" ]; then
    echo "☁️ Testing CloudFront (https://$CLOUDFRONT_DOMAIN)..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://$CLOUDFRONT_DOMAIN" --max-time 15 || echo "000")
    case $RESPONSE in
        200|301|302|404) echo "✅ CloudFront responding (HTTP $RESPONSE)" ;;
        503) echo "⚠️ CloudFront responding but origin unhealthy (HTTP $RESPONSE)" ;;
        000) echo "❌ CloudFront not responding (timeout or still deploying)" ;;
        *) echo "⚠️ CloudFront responding with HTTP $RESPONSE" ;;
    esac
else
    echo "⚠️ CloudFront domain not found"
fi

# Test API Gateway
if [ -n "$API_GATEWAY_URL" ]; then
    echo "🚪 Testing API Gateway ($API_GATEWAY_URL/auth)..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_GATEWAY_URL/auth" --max-time 10 || echo "000")
    case $RESPONSE in
        400|401|403) echo "✅ API Gateway responding (HTTP $RESPONSE - expected for unauthenticated request)" ;;
        200) echo "✅ API Gateway responding (HTTP $RESPONSE)" ;;
        500) echo "⚠️ API Gateway has internal error (HTTP $RESPONSE)" ;;
        000) echo "❌ API Gateway not responding (timeout)" ;;
        *) echo "⚠️ API Gateway responding with HTTP $RESPONSE" ;;
    esac
else
    echo "⚠️ API Gateway URL not found"
fi

# Test Lambda Function URL
if [ -n "$USER_AUTH_URL" ]; then
    echo "⚡ Testing Lambda Function URL..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$USER_AUTH_URL" --max-time 10 || echo "000")
    case $RESPONSE in
        400|401) echo "✅ Lambda Function URL responding (HTTP $RESPONSE - expected for invalid request)" ;;
        200) echo "✅ Lambda Function URL responding (HTTP $RESPONSE)" ;;
        500) echo "⚠️ Lambda Function has internal error (HTTP $RESPONSE)" ;;
        000) echo "❌ Lambda Function URL not responding (timeout)" ;;
        *) echo "⚠️ Lambda Function URL responding with HTTP $RESPONSE" ;;
    esac
else
    echo "⚠️ Lambda Function URL not found"
fi

# Test with sample authentication request
if [ -n "$API_GATEWAY_URL" ]; then
    echo "🔐 Testing authentication endpoint with sample request..."
    AUTH_RESPONSE=$(curl -s -X POST "$API_GATEWAY_URL/auth" \
        -H "Content-Type: application/json" \
        -d '{"username":"test","password":"test"}' \
        --max-time 10 || echo "ERROR")
    
    if [[ "$AUTH_RESPONSE" == *"error"* ]] || [[ "$AUTH_RESPONSE" == *"Invalid"* ]]; then
        echo "✅ Authentication endpoint responding with expected error for invalid credentials"
    elif [[ "$AUTH_RESPONSE" == "ERROR" ]]; then
        echo "❌ Authentication endpoint not responding"
    else
        echo "⚠️ Authentication endpoint responding: $(echo $AUTH_RESPONSE | head -c 100)..."
    fi
fi

echo ""
echo "🎉 Endpoint testing completed!"