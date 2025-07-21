# CodeBuild Service Role
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-codebuild-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CodeBuild Service Role Policy
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*/*",
          "arn:aws:s3:::${var.project_name}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:*",
          "lambda:*",
          "apigateway:*",
          "states:*",
          "sqs:*",
          "sns:*",
          "cloudwatch:*",
          "iam:*",
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# CodeBuild Project for Building and Testing
resource "aws_codebuild_project" "build_project" {
  name          = "${var.project_name}-build-${var.environment}"
  description   = "Build and test project for DOFS application"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/standard:7.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = {
    Name        = "${var.project_name}-build-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CodeBuild Project for Terraform Plan
resource "aws_codebuild_project" "terraform_plan" {
  name          = "${var.project_name}-terraform-plan-${var.environment}"
  description   = "Terraform plan for DOFS infrastructure"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/standard:7.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_VAR_environment"
      value = var.environment
    }

    environment_variable {
      name  = "TF_VAR_project_name"
      value = var.project_name
    }

    environment_variable {
      name  = "TF_VAR_aws_region"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "terraform/buildspec-plan.yml"
  }

  tags = {
    Name        = "${var.project_name}-terraform-plan-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CodeBuild Project for Terraform Apply
resource "aws_codebuild_project" "terraform_apply" {
  name          = "${var.project_name}-terraform-apply-${var.environment}"
  description   = "Terraform apply for DOFS infrastructure"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/standard:7.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_VAR_environment"
      value = var.environment
    }

    environment_variable {
      name  = "TF_VAR_project_name"
      value = var.project_name
    }

    environment_variable {
      name  = "TF_VAR_aws_region"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "terraform/buildspec-apply.yml"
  }

  tags = {
    Name        = "${var.project_name}-terraform-apply-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild_logs" {
  name              = "/aws/codebuild/${var.project_name}-${var.environment}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-codebuild-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}
