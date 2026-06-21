resource "aws_iam_role" "lambda_role" {
  name = "${var.name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name}-lambda-role"
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/lambda/*"
      }
    ]
  })
}

resource "aws_lambda_function" "this" {
  function_name    = "${var.name}-rds-monitor"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12"
  handler          = "rds_monitor.handler"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      DB_IDENTIFIER = var.db_identifier
      REGION        = var.region
    }
  }

  timeout = 30

  tags = merge(var.tags, {
    Name = "${var.name}-rds-monitor"
  })
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.name}-rds-monitor-schedule"
  schedule_expression = var.schedule_expression

  tags = merge(var.tags, {
    Name = "${var.name}-rds-monitor-schedule"
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "${var.name}-rds-monitor-target"
  arn       = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.root}/../lambda/rds_monitor.py"
  output_path = "${path.module}/rds_monitor.zip"
}
