terraform {
  backend "s3" {
      bucket         = "dofs-21-07-25-1"
      key            = "dofs-project/terraform.tfstate"
      region         = "us-west-2"
      encrypt        = true
      use_lockfile   = true
  }
}

# S3 bucket for Terraform state (should be created separately)
# This is commented out as it should be created before running main terraform

resource "aws_s3_bucket" "terraform_state" {
  bucket = "dofs-terraform-state-${random_string.state_suffix.result}"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for Terraform state locking
# NOTE: This table already exists in AWS and should not be managed by this Terraform configuration
# resource "aws_dynamodb_table" "terraform_locks" {
#   name           = "terraform-state-locks"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "LockID"
#
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
#
#   tags = {
#     Name = "Terraform State Lock Table"
#   }
# }

resource "random_string" "state_suffix" {
  length  = 8
  special = false
  upper   = false
}
