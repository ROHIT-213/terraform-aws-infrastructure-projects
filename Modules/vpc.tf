# Create a VPC
resource "aws_vpc" "aws_infra_vpc" {
  cidr_block           = var.vpc_cidr                   //cidr defines IP range
  enable_dns_support   = true                           //Needed for ALB DNS and ECS service discovery
  enable_dns_hostnames = true                           //required for DNS without this DNS won't work.

  tags = {
    Name        = "main"
    Environment = var.environment
  }
}

# Create public subnet 1 in ap-south-1a
resource "aws_subnet" "aws_infra_vpc_pub1" {            //creating public subnet 1 in AZ1a (internet facing resource) 
  vpc_id            = aws_vpc.aws_infra_vpc.id
  cidr_block        = var.pub_subnet_1_cidr
  availability_zone = "ap-south-1a"

  tags = {
    Name        = "AWS_INFRA_PUB1"
    Environment = var.environment
  }
}

# Create public subnet 2 in ap-south-1b
resource "aws_subnet" "aws_infra_vpc_pub2" {            //creating public subnet 1 in AZ1b (internet facing resource)
  vpc_id            = aws_vpc.aws_infra_vpc.id
  cidr_block        = var.pub_subnet_2_cidr
  availability_zone = "ap-south-1b"

  tags = {
    Name        = "AWS_INFRA_PUB2"
    Environment = var.environment
  }
}

# Create private subnet 1 in ap-south-1a
resource "aws_subnet" "aws_infra_vpc_private1" {       //creating private subnet in AZ1a which is used for ECS & RDS
  vpc_id            = aws_vpc.aws_infra_vpc.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = "ap-south-1a"

  tags = {
    Name        = "AWS_INFRA_PRIVATE1"
    Environment = var.environment
  }
}

# Create private subnet 2 in ap-south-1b
resource "aws_subnet" "aws_infra_vpc_private2" {     //creating private subnet in AZ1b which is used for ECS & RDS
  vpc_id            = aws_vpc.aws_infra_vpc.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = "ap-south-1b"

  tags = {
    Name        = "AWS_INFRA_PRIVATE2"
    Environment = var.environment
  }
}
