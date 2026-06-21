variable "name" {
  type        = string
  description = "Resource name prefix"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB"
}

variable "health_check_path" {
  type        = string
  default     = "/health"
  description = "ALB health check path"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}
