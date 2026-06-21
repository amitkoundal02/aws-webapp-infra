output "db_instance_identifier" {
  value = aws_db_instance.this.id
}

output "db_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}
