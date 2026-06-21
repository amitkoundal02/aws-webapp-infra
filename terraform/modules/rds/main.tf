resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-db-subnet-group"
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "RDS security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.asg_security_group_id]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-rds-sg"
  })
}

resource "aws_db_instance" "this" {
  identifier        = "${var.name}-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  username          = var.username
  # production should use manage_master_user_password = true with Secrets Manager
  password                = var.password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 0
  deletion_protection     = false
  apply_immediately       = true

  tags = merge(var.tags, {
    Name = "${var.name}-db"
  })
}
