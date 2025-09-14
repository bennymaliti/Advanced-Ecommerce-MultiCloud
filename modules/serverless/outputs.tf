output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "user_auth_lambda_arn" {
  description = "ARN of the user authentication Lambda function"
  value       = aws_lambda_function.user_authentication.arn
}

output "image_processor_lambda_arn" {
  description = "ARN of the image processor Lambda function"
  value       = aws_lambda_function.image_processor.arn
}

output "custom_metrics_lambda_arn" {
  description = "ARN of the custom metrics Lambda function"
  value       = aws_lambda_function.custom_metrics.arn
}

output "lambda_layer_arn" {
  description = "ARN of the common dependencies Lambda layer"
  value       = aws_lambda_layer_version.common_dependencies.arn
}