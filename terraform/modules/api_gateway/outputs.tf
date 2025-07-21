# terraform/modules/api_gateway/outputs.tf
output "api_url" {
  description = "API Gateway URL"
  value       = "https://${aws_api_gateway_rest_api.dofs_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.dofs_api_stage.stage_name}"
}

output "api_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.dofs_api.id
}

output "stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.dofs_api_stage.stage_name
}

data "aws_region" "current" {}