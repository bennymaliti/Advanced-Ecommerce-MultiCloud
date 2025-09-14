set -e

AWS_REGION=${1:-us-west-2}
BUCKET_NAME=${2:-"advanced-ecommerce-terraform-state-$(date +%s)"}
DYNAMODB_TABLE=${3:-"terraform-state-lock-advanced"}

echo "🏗️  Setting up Terraform backend infrastructure..."
echo "   Region: ${AWS_REGION}"
echo "   S3 Bucket: ${BUCKET_NAME}"
echo "   DynamoDB Table: ${DYNAMODB_TABLE}"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Create S3 bucket for state storage
echo "📦 Creating S3 bucket for Terraform state..."
if aws s3api head-bucket --bucket ${BUCKET_NAME} 2>/dev/null; then
    echo "✅ S3 bucket ${BUCKET_NAME} already exists"
else
    if [ "${AWS_REGION}" = "us-east-1" ]; then
        aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_REGION}
    else
        aws s3api create-bucket \
            --bucket ${BUCKET_NAME} \
            --region ${AWS_REGION} \
            --create-bucket-configuration LocationConstraint=${AWS_REGION}
    fi
    echo "✅ S3 bucket ${BUCKET_NAME} created"
fi

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket ${BUCKET_NAME} \
    --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
    --bucket ${BUCKET_NAME} \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

# Block public access
aws s3api put-public-access-block \
    --bucket ${BUCKET_NAME} \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
echo "🔒 Creating DynamoDB table for state locking..."
if aws dynamodb describe-table --table-name ${DYNAMODB_TABLE} --region ${AWS_REGION} 2>/dev/null; then
    echo "✅ DynamoDB table ${DYNAMODB_TABLE} already exists"
else
    aws dynamodb create-table \
        --table-name ${DYNAMODB_TABLE} \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region ${AWS_REGION}
    
    echo "⏳ Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name ${DYNAMODB_TABLE} --region ${AWS_REGION}
    echo "✅ DynamoDB table ${DYNAMODB_TABLE} created"
fi

echo ""
echo "✅ Backend infrastructure created successfully!"
echo ""
echo "🔧 Update your terraform/main.tf backend configuration:"
echo "backend \"s3\" {"
echo "  bucket         = \"${BUCKET_NAME}\""
echo "  key            = \"advanced-ecommerce/terraform.tfstate\""
echo "  region         = \"${AWS_REGION}\""
echo "  dynamodb_table = \"${DYNAMODB_TABLE}\""
echo "  encrypt        = true"
echo "}"
echo ""
echo "🚀 You can now run 'terraform init' to initialize your backend!"