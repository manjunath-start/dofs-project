variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "lambda_artifacts_bucket" {
  description = "S3 bucket containing Lambda deployment packages"
  type        = string
}

variable "orders_table_name" {
  description = "DynamoDB orders table name"
  type        = string
}

variable "failed_orders_table_name" {
  description = "DynamoDB failed orders table name"
  type        = string
}

variable "order_queue_url" {
  description = "SQS order queue URL"
  type        = string
}

variable "order_queue_arn" {
  description = "SQS order queue ARN"
  type        = string
}

variable "dlq_arn" {
  description = "SQS dead letter queue ARN"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 256
}
