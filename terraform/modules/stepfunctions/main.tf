resource "aws_sfn_state_machine" "order_processor" {
  name     = "${var.project_name}-order-processor-${var.environment}"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "DOFS Order Processing State Machine - Fixed Error Handling"
    StartAt = "ValidateOrder"
    States = {
      ValidateOrder = {
        Type     = "Task"
        Resource = var.validator_lambda_arn
        Next     = "StoreOrder"
        Retry = [
          {
            ErrorEquals   = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "SendToDLQ"
            ResultPath  = "$.error"
          }
        ]
      }
      StoreOrder = {
        Type     = "Task"
        Resource = var.order_storage_lambda_arn
        Next     = "SendToQueue"
        Retry = [
          {
            ErrorEquals   = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "SendToDLQ"
            ResultPath  = "$.error"
          }
        ]
      }
      SendToQueue = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl = var.order_queue_url
          MessageBody = {
            "order_id.$" = "$.order_id"
            "status" = "VALIDATED_AND_STORED"
            "timestamp.$" = "$$.State.EnteredTime"
            "order_data.$" = "$"
          }
        }
        Next = "OrderProcessingComplete"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "OrderProcessingComplete"
            Comment     = "Continue even if SQS fails - order is already stored"
          }
        ]
      }
      SendToDLQ = {
  Type     = "Task"
  Resource = "arn:aws:states:::sqs:sendMessage"
  Parameters = {
          QueueUrl = var.dlq_url
    MessageBody = {
      "order_id.$" = "$.order_id"
      "status" = "FAILED"
      "error_details.$" = "$.error"
      "original_order.$" = "$"
      "timestamp.$" = "$$.State.EnteredTime"
    }
  }
  Next = "OrderProcessingComplete"
  Comment = "Send failed order to SQS DLQ"
}
      OrderProcessingComplete = {
        Type = "Succeed"
        Comment = "Order processing completed (successfully or with handled failures)"
      }
    }
  })

# Temporarily disable logging to resolve IAM issue
  # logging_configuration {
  #   log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
  #   include_execution_data = true
  #   level                  = "ERROR"
  # }

  tags = {
    Environment = var.environment
  }
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/stepfunctions/${var.project_name}-order-processor-${var.environment}"
  retention_in_days = 14
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = "${var.project_name}-step-functions-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_functions_policy" {
  name = "${var.project_name}-step-functions-policy-${var.environment}"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "${var.validator_lambda_arn}*",
          "${var.order_storage_lambda_arn}*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = [
          "arn:aws:sqs:*:*:${var.project_name}-order-queue-${var.environment}",
          "arn:aws:sqs:*:*:${var.project_name}-order-dlq-${var.environment}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}