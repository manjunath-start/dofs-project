variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "api_handler_lambda_arn" {
  description = "ARN of the API handler Lambda function with invoke format"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the API handler Lambda function"
  type        = string
}