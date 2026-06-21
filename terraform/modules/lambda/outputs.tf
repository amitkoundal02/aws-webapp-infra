output "lambda_function_name" {
  value = aws_lambda_function.this.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.this.arn
}

output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.schedule.arn
}
