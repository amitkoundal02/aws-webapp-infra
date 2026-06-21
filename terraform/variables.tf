variable "name" {
  type        = string
  default     = "aws-webapp-infra"
  description = "Resource name prefix"
}

variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "EC2 instance type for ASG"
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 2
}

variable "asg_desired_capacity" {
  type    = number
  default = 1
}

variable "index_html_content" {
  type    = string
  default = "<h1>Welcome to the AWS Web App</h1>\n<p>Healthy</p>"
}

variable "health_html_content" {
  type    = string
  default = "OK"
}

variable "admin_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "Your public IP in CIDR format - set via terraform.tfvars or TF_VAR_admin_cidr_blocks. Get your IP with: curl ifconfig.me"
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type        = string
  description = "Database master password"
  sensitive   = true
}

variable "alert_email" {
  type        = string
  description = "Email address for SNS alerts"
}
