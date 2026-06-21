output "asg_name" {
  value = aws_autoscaling_group.this.name
}

output "launch_template_id" {
  value = aws_launch_template.this.id
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.this.name
}

output "autoscaling_security_group_id" {
  value = aws_security_group.asg.id
}

output "monitor_instance_public_ip" {
  value       = aws_instance.monitor.public_ip
  description = "Public IP of monitoring instance"
}
