terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "aws-webapp-infra-remote-state"
    key          = "terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project     = "aws-webapp-infra"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source     = "./modules/vpc"
  name       = var.name
  cidr_block = var.vpc_cidr
  public_subnets = {
    a = {
      cidr = "10.0.1.0/24"
      az   = "ap-south-1a"
    }
    b = {
      cidr = "10.0.2.0/24"
      az   = "ap-south-1b"
    }
  }
  private_subnets = {
    a = {
      cidr = "10.0.3.0/24"
      az   = "ap-south-1a"
    }
    b = {
      cidr = "10.0.4.0/24"
      az   = "ap-south-1b"
    }
  }
  tags = local.tags
}

module "alb" {
  source            = "./modules/alb"
  name              = var.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  tags              = local.tags
}

module "asg" {
  source                = "./modules/asg"
  name                  = var.name
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn
  instance_type         = var.instance_type
  key_name              = var.key_name
  min_size              = var.asg_min_size
  max_size              = var.asg_max_size
  desired_capacity      = var.asg_desired_capacity
  index_html_content    = var.index_html_content
  health_html_content   = var.health_html_content
  admin_cidr_blocks     = var.admin_cidr_blocks
  tags                  = local.tags
}

module "rds" {
  source                = "./modules/rds"
  name                  = var.name
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  asg_security_group_id = module.asg.autoscaling_security_group_id
  username              = var.db_username
  password              = var.db_password
  tags                  = local.tags
}

resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"

  tags = merge(local.tags, {
    Name = "${var.name}-alerts"
  })
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

module "lambda" {
  source        = "./modules/lambda"
  name          = var.name
  sns_topic_arn = aws_sns_topic.alerts.arn
  db_identifier = module.rds.db_instance_identifier
  region        = var.aws_region
  tags          = local.tags
}
