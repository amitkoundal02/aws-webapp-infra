variable "name" {
  type        = string
  description = "Resource name prefix"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for RDS"
}

variable "asg_security_group_id" {
  type        = string
  description = "Security group ID allowed to access RDS"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "username" {
  type        = string
  description = "Database master username"
}

variable "password" {
  type        = string
  description = "Database master password"
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}
