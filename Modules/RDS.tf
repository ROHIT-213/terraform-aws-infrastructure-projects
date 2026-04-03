# IAM Role for RDS Enhanced Monitoring

resource "aws_iam_role" "rds_monitoring_role" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "rds-monitoring-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Security Group for RDS - allow access only from ECS SG

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow PostgreSQL access only from ECS containers"
  vpc_id      = aws_vpc.aws_infra_vpc.id

  ingress {
    description     = "PostgreSQL from ECS only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]                               //Only ECS can access DB
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "rds-sg"
    Environment = var.environment
  }
}

# DB Subnet Group - places RDS in private subnets

resource "aws_db_subnet_group" "pg_subnet_grp" {
  name        = "pg-subnet-group"
  description = "RDS subnet group for private subnets"
  subnet_ids  = [aws_subnet.aws_infra_vpc_private1.id, aws_subnet.aws_infra_vpc_private2.id]         //Ensure DB is private

  tags = {
    Name        = "pg-subnet-group"
    Environment = var.environment
  }
}

# RDS PostgreSQL Instance

resource "aws_db_instance" "rds_pg" {
  identifier        = "rds-pg"
  engine            = "postgres"                                       //PostgreSQL DB
  engine_version    = var.rds_engine_version
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  storage_type      = "gp3"
  db_name           = "appdb"

  username                    = "appdbadmin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.pg_subnet_grp.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false                                          //secure (No Internet access)

  # Multi-AZ (disabled for free tier)
  multi_az = false

  # Automated backups (disabled for free tier)
  backup_retention_period    = 0
  copy_tags_to_snapshot      = true
  final_snapshot_identifier  = "rds-pg-final-snapshot"
  skip_final_snapshot        = false
  auto_minor_version_upgrade = true

  # Encryption
  storage_encrypted = true

  # IAM authentication
  iam_database_authentication_enabled = true

  # Enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring_role.arn

  # Performance Insights
  performance_insights_enabled = true

  tags = {
    Name        = "rds-pg"
    Environment = var.environment
  }
}
