output "order_queue_url" {
  description = "Order queue URL"
  value       = aws_sqs_queue.order_queue.url
}

output "order_queue_arn" {
  description = "Order queue ARN"
  value       = aws_sqs_queue.order_queue.arn
}

output "dlq_url" {
  description = "Dead letter queue URL"
  value       = aws_sqs_queue.order_dlq.url
}

output "dlq_arn" {
  description = "Dead letter queue ARN"
  value       = aws_sqs_queue.order_dlq.arn
}
