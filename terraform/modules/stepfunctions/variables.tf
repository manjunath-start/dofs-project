variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "validator_lambda_arn" {
  description = "ARN of the validator Lambda function"
  type        = string
}

variable "order_storage_lambda_arn" {
  description = "ARN of the order storage Lambda function"
  type        = string
}

variable "order_queue_url" {
  description = "SQS order queue URL"
  type        = string
}