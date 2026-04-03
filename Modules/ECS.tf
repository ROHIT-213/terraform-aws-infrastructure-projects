# IAM Role for ECS EC2 instances

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }         //Allows EC2 to talk to ECS
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "ecs-instance-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# IAM Role for ECS Task Execution

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }         //Allows container -> pull image, send logs
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "ecs-task-execution-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security Group for ECS EC2 instances

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-instances-sg"
  description = "Security group for ECS EC2 instances in private subnets"
  vpc_id      = aws_vpc.aws_infra_vpc.id

  ingress {
    description     = "Allow HTTP only from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]                          //only ALB can access ECS
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ecs-instances-sg"
    Environment = var.environment
  }
}

# CloudWatch Log Group for ECS container logs

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/app-task"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cloudwatch_key.arn

  tags = {
    Name        = "ecs-log-group"
    Environment = var.environment
  }
}

# ECS Cluster

resource "aws_ecs_cluster" "ecs_cluster" {                                 //Logical grouping of containers
  name = "ECS-PR1A"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "ECS-PR1A"
    Environment = var.environment
  }
}

# Launch Template for ECS EC2 instances

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "ecs-launch-template-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.ecs_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ecs_sg.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
  EOF
  )                                                                                  //Attach EC2 -> ECS cluster

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "ecs-instance"
      Environment = var.environment
    }
  }
}

# Auto Scaling Group in private subnets

resource "aws_autoscaling_group" "ecs_asg" {
  name                = "ecs-asg"
  min_size            = var.ecs_min_size
  max_size            = var.ecs_max_size
  desired_capacity    = var.ecs_desired_capacity
  vpc_zone_identifier = [
    aws_subnet.aws_infra_vpc_private1.id,
    aws_subnet.aws_infra_vpc_private2.id
  ]

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "ecs-asg-instance"
    propagate_at_launch = true
  }
}

# ECS Capacity Provider linked to ASG

resource "aws_ecs_capacity_provider" "ecs_cp" {
  name = "app-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn

    managed_scaling {                                 //ECS automatically scales EC2 instances  
      status                    = "ENABLED"
      target_capacity           = 80
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2                   //Controls number of EC2 instances
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs_cluster_cp" {
  cluster_name       = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.ecs_cp.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_cp.name
    weight            = 1
    base              = 1
  }
}
