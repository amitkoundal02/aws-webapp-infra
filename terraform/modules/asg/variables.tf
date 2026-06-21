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
  description = "Public subnet IDs for ASG instances"
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group ID for ALB to allow inbound traffic"
}

variable "target_group_arn" {
  type        = string
  description = "ALB target group ARN"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "index_html_content" {
  type        = string
  description = "HTML content for the web root"
}

variable "health_html_content" {
  type        = string
  description = "Content for the health check endpoint"
}

variable "admin_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed SSH access to ASG instances"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name for SSH access"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}
