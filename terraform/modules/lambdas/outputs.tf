data "aws_region" "current" {}

output "api_handler_lambda_arn" {
  description = "API Handler Lambda ARN for API Gateway integration"
  value       = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.api_handler.arn}/invocations"
}

output "api_handler_function_name" {
  description = "API Handler Lambda function name"
  value       = aws_lambda_function.api_handler.function_name
}

output "validator_lambda_arn" {
  description = "Validator Lambda ARN for API Gateway integration"
  value       = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.validator.arn}/invocations"
}

output "validator_function_name" {
  description = "Validator Lambda function name"
  value       = aws_lambda_function.validator.function_name
}

output "order_storage_lambda_arn" {
  description = "Order Storage Lambda ARN for API Gateway integration"
  value       = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.order_storage.arn}/invocations"
}

output "order_storage_function_name" {
  description = "Order Storage Lambda function name"
  value       = aws_lambda_function.order_storage.function_name
}

output "fulfill_order_lambda_arn" {
  description = "Fulfill Order Lambda ARN for API Gateway integration"
  value       = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.fulfill_order.arn}/invocations"
}

output "fulfill_order_function_name" {
  description = "Fulfill Order Lambda function name"
  value       = aws_lambda_function.fulfill_order.function_name
}

# Direct Lambda ARNs for Step Functions (not API Gateway integration ARNs)
output "validator_lambda_function_arn" {
  description = "Validator Lambda function ARN (direct, not API Gateway)"
  value       = aws_lambda_function.validator.arn
}

output "order_storage_lambda_function_arn" {
  description = "Order Storage Lambda function ARN (direct, not API Gateway)"
  value       = aws_lambda_function.order_storage.arn
}