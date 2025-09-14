# Lambda Execution Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# Lambda Custom Policy
resource "aws_iam_role_policy" "lambda_custom_policy" {
  name = "${var.project_name}-lambda-custom-policy"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "s3:GetObject",
          "s3:PutObject",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "rekognition:DetectLabels",
          "rekognition:DetectText",
          "cognito-idp:AdminInitiateAuth",
          "secretsmanager:GetSecretValue",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# User Authentication Lambda
resource "aws_lambda_function" "user_authentication" {
  filename         = var.lambda_zip_files["user_auth"]
  function_name    = "${var.project_name}-user-authentication"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "handler.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 512
  
  environment {
    variables = {
      USER_POOL_ID = var.cognito_user_pool_id
      CLIENT_ID    = var.cognito_client_id
      JWT_SECRET   = var.jwt_secret
      ENVIRONMENT  = var.environment
    }
  }
  
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }
  
  tracing_config {
    mode = "Active"
  }
  
  tags = var.tags
}

# Image Processing Lambda
resource "aws_lambda_function" "image_processor" {
  filename         = var.lambda_zip_files["image_processor"]
  function_name    = "${var.project_name}-image-processor"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "handler.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  memory_size     = 1024
  
  environment {
    variables = {
      S3_BUCKET          = var.s3_bucket_name
      DYNAMODB_TABLE     = var.dynamodb_table_name
      REKOGNITION_REGION = var.aws_region
    }
  }
  
  tracing_config {
    mode = "Active"
  }
  
  tags = var.tags
}

# Custom Metrics Lambda
resource "aws_lambda_function" "custom_metrics" {
  filename         = var.lambda_zip_files["custom_metrics"]
  function_name    = "${var.project_name}-custom-metrics"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "handler.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  memory_size     = 256
  
  environment {
    variables = {
      CLOUDWATCH_NAMESPACE = "ECommerce/Application"
      ENVIRONMENT          = var.environment
    }
  }
  
  tags = var.tags
}

# EventBridge Rules for Custom Metrics
resource "aws_cloudwatch_event_rule" "metrics_schedule" {
  name                = "${var.project_name}-metrics-schedule"
  description         = "Trigger custom metrics collection"
  schedule_expression = "rate(5 minutes)"
  
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.metrics_schedule.name
  target_id = "CustomMetricsLambdaTarget"
  arn       = aws_lambda_function.custom_metrics.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_metrics.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.metrics_schedule.arn
}

# Lambda Layers for Common Dependencies
resource "aws_lambda_layer_version" "common_dependencies" {
  filename         = var.lambda_layer_zip
  layer_name       = "${var.project_name}-common-dependencies"
  description      = "Common dependencies for Lambda functions"
  
  compatible_runtimes = ["python3.9"]
  
  source_code_hash = filebase64sha256(var.lambda_layer_zip)
}