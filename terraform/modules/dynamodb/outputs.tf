output "orders_table_name" {
  description = "Orders table name"
  value       = aws_dynamodb_table.orders.name
}

output "orders_table_arn" {
  description = "Orders table ARN"
  value       = aws_dynamodb_table.orders.arn
}

output "failed_orders_table_name" {
  description = "Failed orders table name"
  value       = aws_dynamodb_table.failed_orders.name
}

output "failed_orders_table_arn" {
  description = "Failed orders table ARN"
  value       = aws_dynamodb_table.failed_orders.arn
}
