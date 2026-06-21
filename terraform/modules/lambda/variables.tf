variable "name" {
  type        = string
  description = "Resource name prefix"
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for alerts"
}

variable "db_identifier" {
  type        = string
  description = "RDS DB instance identifier"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "schedule_expression" {
  type    = string
  default = "rate(5 minutes)"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}
