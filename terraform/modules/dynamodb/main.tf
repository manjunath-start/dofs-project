resource "aws_dynamodb_table" "orders" {
  name           = "${var.project_name}-orders-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name     = "status-created_at-index"
    hash_key = "status"
    range_key = "created_at"
    projection_type = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-orders-${var.environment}"
    Environment = var.environment
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}

resource "aws_dynamodb_table" "failed_orders" {
  name           = "${var.project_name}-failed-orders-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  attribute {
    name = "failed_at"
    type = "S"
  }

  global_secondary_index {
    name      = "failed_at-index"
    hash_key  = "failed_at"
    projection_type = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-failed-orders-${var.environment}"
    Environment = var.environment
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}