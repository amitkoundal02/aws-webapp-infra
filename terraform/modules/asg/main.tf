data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}

resource "aws_iam_role" "instance_role" {
  name = "${var.name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name}-instance-role"
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.instance_role.name

  tags = merge(var.tags, {
    Name = "${var.name}-instance-profile"
  })
}

resource "aws_iam_role_policy" "instance_policy" {
  name = "${var.name}-instance-policy"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::aws-webapp-infra-remote-state",
          "arn:aws:s3:::aws-webapp-infra-remote-state/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:GetParameter"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "asg" {
  name        = "${var.name}-asg-sg"
  description = "Security group for ASG instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
    description = "SSH access for Ansible"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-asg-sg"
  })
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  key_name      = var.key_name
  instance_type = var.instance_type
  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  network_interfaces {
    security_groups             = [aws_security_group.asg.id]
    associate_public_ip_address = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    index_content  = var.index_html_content,
    health_content = var.health_html_content
  }))

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name = "${var.name}-instance"
    })
  }
}

resource "aws_autoscaling_group" "this" {
  name_prefix         = "${var.name}-asg-"
  max_size            = var.max_size
  min_size            = var.min_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.public_subnet_ids
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  target_group_arns = [var.target_group_arn]

  health_check_type         = "ELB"
  health_check_grace_period = 60

  dynamic "tag" {
    for_each = merge(var.tags, {
      Name = "${var.name}-asg"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_scale_out" {
  alarm_name          = "${var.name}-cpu-scale-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out when average CPU exceeds 70%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_out.arn]

  tags = merge(var.tags, {
    Name = "${var.name}-cpu-scale-out"
  })
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.name}-scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}
