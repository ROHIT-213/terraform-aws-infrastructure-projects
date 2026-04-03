# Security Group for ALB

resource "aws_security_group" "lb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP inbound traffic to ALB"
  vpc_id      = aws_vpc.aws_infra_vpc.id

  ingress {
    description = "Allow HTTP from internet"             //Allow internet -> ALB
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Application Load Balancer in public subnets

resource "aws_lb" "alb" {                              //Entry point of application and it Distributes traffic
  name                       = "alb-tf"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lb_sg.id]
  subnets                    = [aws_subnet.aws_infra_vpc_pub1.id, aws_subnet.aws_infra_vpc_pub2.id]   //HA across AZ's
  enable_deletion_protection = false                  //set false to delete all infra set true only if you don't want to delete

  tags = {
    Environment = var.environment
  }
}

# Target Group for ECS tasks

resource "aws_lb_target_group" "alb_tg" {
  name        = "tf-alb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.aws_infra_vpc.id
  target_type = "ip"                                 //ECS uses ENI -> so target = IP (not instance id like EC2)

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "tf-alb-tg"
  }
}

# Listener routing HTTP traffic to ECS target group

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.alb_tg.arn
    type             = "forward"                                     //Route trafgic -> ECS
  }
}

# ECS Task Definition

resource "aws_ecs_task_definition" "app" {
  family                   = "app-task"                                 //A logical name/group for the task definition
  network_mode             = "awsvpc"                                   //Each container gets its own IP from the VPC subnet
  requires_compatibilities = ["EC2"]                                    //Tells ECS this task must run on EC2 instances (not Fargate)
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn   //Grants ECS permission to pull the container image from ECR and write logs to CloudWatch (without this ECS can't start the container)
  cpu                      = "256"                                      //Reserves 256 CPU units (0.25 vCPU)
  memory                   = "512"                                      //Reserves 512 MB of RAM

  container_definitions = jsonencode([{
    name      = "app"                                                    //container name
    image     = "nginx:latest"                                           //Demo app
    essential = true                                                     //if container crashes, the entire task stops
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
  }])
}

# ECS Service wired to ALB

resource "aws_ecs_service" "app_service" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2                                                  //Always keep 2 containers running

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_cp.name
    weight            = 1
    base              = 1
  }

  network_configuration {
    subnets         = [aws_subnet.aws_infra_vpc_private1.id, aws_subnet.aws_infra_vpc_private2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {                                                    //connects ECS -> ALB
    target_group_arn = aws_lb_target_group.alb_tg.arn
    container_name   = "app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.front_end]
}
