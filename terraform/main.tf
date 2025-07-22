# terraform/main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "DOFS"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 bucket for Lambda deployment packages
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "${var.project_name}-lambda-artifacts-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# DynamoDB Module
module "dynamodb" {
  source = "./modules/dynamodb"
  
  project_name = var.project_name
  environment  = var.environment
}

# SQS Module
module "sqs" {
  source = "./modules/sqs"
  
  project_name               = var.project_name
  environment                = var.environment
  visibility_timeout_seconds = var.visibility_timeout_seconds
  max_receive_count          = var.max_receive_count
  failed_orders_table_name   = module.dynamodb.failed_orders_table_name
}

# Lambda Module
module "lambdas" {
  source = "./modules/lambdas"

  project_name        = var.project_name
  environment         = var.environment
  lambda_runtime      = var.lambda_runtime
  lambda_timeout      = var.lambda_timeout
  lambda_memory_size  = var.lambda_memory_size

  # Required dependencies
  orders_table_name        = module.dynamodb.orders_table_name
  failed_orders_table_name = module.dynamodb.failed_orders_table_name
  lambda_artifacts_bucket  = aws_s3_bucket.lambda_artifacts.bucket
  order_queue_url          = module.sqs.order_queue_url
  order_queue_arn          = module.sqs.order_queue_arn
  dlq_arn                  = module.sqs.dlq_arn
}

# Step Functions Module
module "stepfunctions" {
  source = "./modules/stepfunctions"
  
  project_name = var.project_name
  environment  = var.environment

  validator_lambda_arn     = module.lambdas.validator_lambda_function_arn
  order_storage_lambda_arn = module.lambdas.order_storage_lambda_function_arn
  order_queue_url          = module.sqs.order_queue_url
  dlq_url                  = module.sqs.dlq_url
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api_gateway"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Lambda function details
  api_handler_lambda_arn = module.lambdas.api_handler_lambda_arn
  lambda_function_name   = module.lambdas.api_handler_function_name
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  project_name         = var.project_name
  environment          = var.environment
  alert_email          = var.alert_email
  dlq_alarm_threshold  = var.dlq_alarm_threshold
  dlq_arn              = module.sqs.dlq_arn
}

# CI/CD Module
module "cicd" {
  source = "./cicd"
  
  project_name             = var.project_name
  environment              = var.environment
  aws_region               = var.aws_region
  github_repo              = var.github_repo
  github_token_secret_name = var.github_token_secret_name
  alert_email              = var.alert_email
  codestar_connection_arn  = var.codestar_connection_arn
}

# Upload Lambda deployment packages
resource "aws_s3_object" "lambda_packages" {
  for_each = {
    "api_handler"    = "../lambdas/api_handler/deployment.zip"
    "validator"      = "../lambdas/validator/deployment.zip"
    "order_storage"  = "../lambdas/order_storage/deployment.zip"
    "fulfill_order"  = "../lambdas/fulfill_order/deployment.zip"
  }
  
  bucket = aws_s3_bucket.lambda_artifacts.bucket
  key    = "${each.key}/deployment.zip"
  source = each.value
  etag   = filemd5(each.value)
}