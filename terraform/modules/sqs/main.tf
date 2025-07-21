resource "aws_sqs_queue" "order_dlq" {
  name = "${var.project_name}-order-dlq-${var.environment}"

  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name        = "${var.project_name}-order-dlq-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "order_queue" {
  name                      = "${var.project_name}-order-queue-${var.environment}"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds = 345600 # 4 days
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name        = "${var.project_name}-order-queue-${var.environment}"
    Environment = var.environment
  }
}

# Lambda for processing DLQ messages
resource "aws_lambda_function" "dlq_processor" {
  function_name = "${var.project_name}-dlq-processor-${var.environment}"
  role          = aws_iam_role.dlq_processor_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  filename      = "${path.module}/dlq_processor.zip"
  source_code_hash = data.archive_file.dlq_processor_zip.output_base64sha256

  environment {
    variables = {
      FAILED_ORDERS_TABLE_NAME = var.failed_orders_table_name
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [aws_iam_role_policy_attachment.dlq_processor_basic_execution]
}

# Create DLQ processor Lambda deployment package
data "archive_file" "dlq_processor_zip" {
  type        = "zip"
  output_path = "${path.module}/dlq_processor.zip"
  source {
    content = file("${path.module}/dlq_processor.py")
    filename = "lambda_function.py"
  }
}

# IAM role for DLQ processor
resource "aws_iam_role" "dlq_processor_role" {
  name = "${var.project_name}-dlq-processor-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dlq_processor_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.dlq_processor_role.name
}

resource "aws_iam_role_policy" "dlq_processor_policy" {
  name = "${var.project_name}-dlq-processor-policy-${var.environment}"
  role = aws_iam_role.dlq_processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.order_dlq.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.failed_orders_table_name}"
      }
    ]
  })
}

# SQS trigger for DLQ processor
resource "aws_lambda_event_source_mapping" "dlq_trigger" {
  event_source_arn = aws_sqs_queue.order_dlq.arn
  function_name    = aws_lambda_function.dlq_processor.arn
  batch_size       = 1
  enabled          = true

  depends_on = [aws_iam_role_policy.dlq_processor_policy]
}