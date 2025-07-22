data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Common Lambda execution role
resource "aws_iam_role" "lambda_execution_role" {
  name               = "${var.project_name}-lambda-execution-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# Lambda policy for DynamoDB, SQS, and Step Functions
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:BatchGetItem",
      "dynamodb:DescribeTable"
    ]
    
    resources = [
      "arn:aws:dynamodb:*:*:table/${var.orders_table_name}",
      "arn:aws:dynamodb:*:*:table/${var.failed_orders_table_name}",
      "arn:aws:dynamodb:*:*:table/${var.orders_table_name}/index/*",
      "arn:aws:dynamodb:*:*:table/${var.failed_orders_table_name}/index/*"
    ]
  }

  statement {
    effect = "Allow"
    
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    
    resources = [
      var.order_queue_arn,
      var.dlq_arn
    ]
  }

  statement {
    effect = "Allow"
    
    actions = [
      "states:StartExecution"
    ]
    
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "${var.project_name}-lambda-policy-${var.environment}"
  role   = aws_iam_role.lambda_execution_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# API Handler Lambda
resource "aws_lambda_function" "api_handler" {
  function_name = "${var.project_name}-api-handler-${var.environment}"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  s3_bucket = var.lambda_artifacts_bucket
  s3_key    = "api_handler/deployment.zip"

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT_NAME = var.project_name
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# Validator Lambda
resource "aws_lambda_function" "validator" {
  function_name = "${var.project_name}-validator-${var.environment}"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  s3_bucket = var.lambda_artifacts_bucket
  s3_key    = "validator/deployment.zip"

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-order-storage-${var.environment}"
    Environment = var.environment
    Region      = data.aws_region.current.name
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# Order Storage Lambda
resource "aws_lambda_function" "order_storage" {
  function_name = "${var.project_name}-order-storage-${var.environment}"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  s3_bucket = var.lambda_artifacts_bucket
  s3_key    = "order_storage/deployment.zip"

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.orders_table_name
      ORDER_QUEUE_URL = var.order_queue_url
      ENVIRONMENT = var.environment
      REGION = data.aws_region.current.name  # Changed from AWS_REGION
      FAILED_ORDERS_TABLE_NAME = var.failed_orders_table_name
      DEBUG_LOGGING = "true"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# Fulfill Order Lambda
resource "aws_lambda_function" "fulfill_order" {
  function_name = "${var.project_name}-fulfill-order-${var.environment}"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  s3_bucket = var.lambda_artifacts_bucket
  s3_key    = "fulfill_order/deployment.zip"

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.orders_table_name
      FAILED_ORDERS_TABLE_NAME = var.failed_orders_table_name
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# SQS trigger for fulfill order lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.order_queue_arn
  function_name    = aws_lambda_function.fulfill_order.arn
  batch_size       = 1
  enabled          = true

  depends_on = [aws_iam_role_policy.lambda_policy]
}