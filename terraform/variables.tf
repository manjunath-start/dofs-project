# terraform/variables.tf
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dofs"
}

variable "alert_email" {
  description = "Email address for DLQ alerts"
  type        = string
  default     = "manjunath.dc1995@gamil.com"
}

variable "github_repo" {
  description = "GitHub repository for CI/CD"
  type        = string
  default     = "manjunath-start/dofs-project"
}

variable "github_token_secret_name" {
  description = "Name of the AWS Secrets Manager secret containing GitHub token"
  type        = string
  default     = "github-token-1"
}

# Lambda configuration
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

# SQS configuration
variable "visibility_timeout_seconds" {
  description = "SQS visibility timeout"
  type        = number
  default     = 300
}

variable "max_receive_count" {
  description = "Maximum number of receives before moving to DLQ"
  type        = number
  default     = 3
}

# DLQ monitoring
variable "dlq_alarm_threshold" {
  description = "DLQ message count threshold for alerts"
  type        = number
  default     = 5
}

# CodeStar Connection configuration
variable "codestar_connection_arn" {
  description = "ARN of the CodeStar Connection"
  type        = string
  default     = "arn:aws:codeconnections:us-west-2:412381764327:connection/7d26847e-722d-4bdd-8701-26d7fc5956cb"
}