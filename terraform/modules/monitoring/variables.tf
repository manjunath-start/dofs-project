variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "dlq_arn" {
  description = "DLQ ARN for monitoring"
  type        = string
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
}

variable "dlq_alarm_threshold" {
  description = "DLQ message count threshold for alerts"
  type        = number
  default     = 5
}