variable "name" {
  type        = string
  description = "Resource name prefix"
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR block"
}

variable "public_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
  description = "Public subnets definitions"
}

variable "private_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
  description = "Private subnets definitions"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}
