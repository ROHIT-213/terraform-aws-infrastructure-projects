# KMS Key for CloudWatch Log Group encryption

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "cloudwatch_key" {                                      //Encrypt logs
  description             = "KMS key for CloudWatch log group encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM root permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "cloudwatch-kms-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "cloudwatch_key_alias" {
  name          = "alias/cloudwatch-logs-key"
  target_key_id = aws_kms_key.cloudwatch_key.key_id
}

# IAM Role for VPC Flow Logs

resource "aws_iam_role" "flow_logs_role" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "vpc-flow-logs-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "flow_logs_policy" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

# CloudWatch Log Group for VPC Flow Logs

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cloudwatch_key.arn

  tags = {
    Name        = "vpc-flow-logs"
    Environment = var.environment
  }
}

# VPC Flow Logs

resource "aws_flow_log" "vpc_flow_log" {
  vpc_id          = aws_vpc.aws_infra_vpc.id
  traffic_type    = "ALL"                                                  //Monitor all traffic 
  iam_role_arn    = aws_iam_role.flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn

  tags = {
    Name        = "vpc-flow-log"
    Environment = var.environment
  }
}

# CloudWatch Alarm - ECS CPU Utilization

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_alarm" {
  alarm_name          = "ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"                            //Alerts on high load
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilization exceeded 80%"

  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
    ServiceName = aws_ecs_service.app_service.name
  }

  tags = {
    Environment = var.environment
  }
}

# CloudWatch Alarm - RDS CPU Utilization

resource "aws_cloudwatch_metric_alarm" "rds_cpu_alarm" {
  alarm_name          = "rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"                              //Alerts on high load
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization exceeded 80%"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds_pg.identifier
  }

  tags = {
    Environment = var.environment
  }
}
