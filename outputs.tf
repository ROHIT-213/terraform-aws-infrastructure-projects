output "vpc_id" {
  description = "VPC ID"
  value       = module.infra.vpc_id
}

output "public_subnet_1_id" {
  description = "Public subnet 1 ID (us-west-1a)"
  value       = module.infra.public_subnet_1_id
}

output "public_subnet_2_id" {
  description = "Public subnet 2 ID (us-west-1b)"
  value       = module.infra.public_subnet_2_id
}

output "private_subnet_1_id" {
  description = "Private subnet 1 ID (us-west-1a)"
  value       = module.infra.private_subnet_1_id
}

output "private_subnet_2_id" {
  description = "Private subnet 2 ID (us-west-1b)"
  value       = module.infra.private_subnet_2_id
}

output "alb_dns_name" {                                                //Gives you URL to access app
  description = "ALB DNS name to access the application"
  value       = module.infra.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.infra.ecs_cluster_name
}

output "rds_endpoint" {                                                //DB connection endpoint
  description = "RDS PostgreSQL endpoint"
  value       = module.infra.rds_endpoint
  sensitive   = true
}

output "nat_gateway_ip" {
  description = "Elastic IP of the NAT Gateway"
  value       = module.infra.nat_gateway_ip
}
