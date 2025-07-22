# terraform/outputs.tf
output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_url
}

output "api_endpoint" {
  description = "Complete API endpoint URL for orders"
  value       = "${module.api_gateway.api_url}/order"
}

output "curl_example" {
  description = "Example curl command to test the API"
  value       = "curl -X POST ${module.api_gateway.api_url}/order -H 'Content-Type: application/json' -d '{\"order_id\":\"12345\",\"customer_name\":\"Test User\",\"items\":[{\"item\":\"Product A\",\"quantity\":1}],\"total_amount\":25.99}'"
}

output "api_gateway_stage" {
  description = "API Gateway stage"
  value       = module.api_gateway.stage_name
}

output "step_function_arn" {
  description = "Step Function ARN"
  value       = module.stepfunctions.state_machine_arn
}

output "orders_table_name" {
  description = "Orders DynamoDB table name"
  value       = module.dynamodb.orders_table_name
}

output "failed_orders_table_name" {
  description = "Failed orders DynamoDB table name"
  value       = module.dynamodb.failed_orders_table_name
}

output "order_queue_url" {
  description = "SQS order queue URL"
  value       = module.sqs.order_queue_url
}

output "dlq_url" {
  description = "SQS dead letter queue URL"
  value       = module.sqs.dlq_url
}

output "lambda_artifacts_bucket" {
  description = "S3 bucket for Lambda artifacts"
  value       = aws_s3_bucket.lambda_artifacts.bucket
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

# Lambda function names for debugging
output "lambda_functions" {
  description = "Lambda function names"
  value = {
    api_handler    = module.lambdas.api_handler_function_name
    validator      = module.lambdas.validator_function_name
    order_storage  = module.lambdas.order_storage_function_name
    fulfill_order  = module.lambdas.fulfill_order_function_name
  }
}

# CloudWatch Log Groups
output "log_groups" {
  description = "CloudWatch Log Group names"
  value = {
    api_handler    = "/aws/lambda/${module.lambdas.api_handler_function_name}"
    validator      = "/aws/lambda/${module.lambdas.validator_function_name}"
    order_storage  = "/aws/lambda/${module.lambdas.order_storage_function_name}"
    fulfill_order  = "/aws/lambda/${module.lambdas.fulfill_order_function_name}"
    step_functions = "/aws/stepfunctions/${var.project_name}-order-processor-${var.environment}"
  }
}