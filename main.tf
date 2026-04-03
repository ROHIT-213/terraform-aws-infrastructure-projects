terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "infra" {
  source = "./Modules"                                        //logic is inside modules

  vpc_cidr              = var.vpc_cidr                        //passing variables into modules to reuse
  pub_subnet_1_cidr     = var.pub_subnet_1_cidr
  pub_subnet_2_cidr     = var.pub_subnet_2_cidr
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
  ecs_instance_type     = var.ecs_instance_type
  ecs_min_size          = var.ecs_min_size
  ecs_max_size          = var.ecs_max_size
  ecs_desired_capacity  = var.ecs_desired_capacity
  rds_instance_class    = var.rds_instance_class
  rds_allocated_storage = var.rds_allocated_storage
  rds_engine_version    = var.rds_engine_version
  environment           = var.environment
}
