# Outputs da VPC
output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block da VPC"
  value       = module.vpc.vpc_cidr_block
}
/*
# Outputs das Subnets
output "public_subnet_id" {
  description = "ID da subnet pública"
  value       = module.subnets.public_subnet_id
}

output "public_subnet_cidr" {
  description = "CIDR block da subnet pública"
  value       = module.subnets.public_subnet_cidr
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = module.subnets.private_subnet_ids
}

output "private_subnet_cidrs" {
  description = "CIDR blocks das subnets privadas"
  value       = module.subnets.private_subnet_cidrs
}

# Outputs dos Gateways
output "internet_gateway_id" {
  description = "ID do Internet Gateway"
  value       = module.gateways.internet_gateway_id
}

output "nat_gateway_id" {
  description = "ID do NAT Gateway"
  value       = module.gateways.nat_gateway_id
}

output "nat_gateway_public_ip" {
  description = "IP público do NAT Gateway"
  value       = module.gateways.nat_gateway_public_ip
}

# Outputs das Route Tables
output "public_route_table_id" {
  description = "ID da route table pública"
  value       = module.routing.public_route_table_id
}

output "private_route_table_id" {
  description = "ID da route table privada"
  value       = module.routing.private_route_table_id
}

# Outputs das Availability Zones
output "availability_zones" {
  description = "Availability zones utilizadas"
  value       = module.subnets.availability_zones
}
*/
