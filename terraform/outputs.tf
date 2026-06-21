output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "asg_name" {
  value = module.asg.asg_name
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "lambda_function_name" {
  value = module.lambda.lambda_function_name
}

output "monitor_public_ip" {
  value       = module.asg.monitor_instance_public_ip
  description = "Public IP of Prometheus/Grafana monitor"
}
