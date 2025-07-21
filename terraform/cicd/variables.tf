variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository for CI/CD"
  type        = string
}

variable "github_token_secret_name" {
  description = "Name of the AWS Secrets Manager secret containing GitHub token"
  type        = string
}

variable "alert_email" {
  description = "Email address for pipeline alerts"
  type        = string
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar Connection for GitHub integration"
  type        = string
}