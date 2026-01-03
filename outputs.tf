# Outputs da VPC
output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "ARN da VPC"
  value       = aws_vpc.main.arn
}

output "vpc_cidr_block" {
  description = "CIDR block principal da VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_additional_cidr_blocks" {
  description = "Lista de CIDR blocks adicionais associados à VPC"
  value       = aws_vpc_ipv4_cidr_block_association.main[*].cidr_block
}

output "vpc_default_security_group_id" {
  description = "ID do security group padrão da VPC"
  value       = aws_vpc.main.default_security_group_id
}

output "vpc_default_network_acl_id" {
  description = "ID da Network ACL padrão da VPC"
  value       = aws_vpc.main.default_network_acl_id
}

output "vpc_default_route_table_id" {
  description = "ID da route table padrão da VPC"
  value       = aws_vpc.main.default_route_table_id
}

output "vpc_main_route_table_id" {
  description = "ID da route table principal da VPC"
  value       = aws_vpc.main.main_route_table_id
}

output "vpc_owner_id" {
  description = "ID do proprietário da VPC"
  value       = aws_vpc.main.owner_id
}

output "vpc_enable_dns_hostnames" {
  description = "Status do DNS hostnames na VPC"
  value       = aws_vpc.main.enable_dns_hostnames
}

output "vpc_enable_dns_support" {
  description = "Status do DNS support na VPC"
  value       = aws_vpc.main.enable_dns_support
}

# Outputs das Public Subnets
output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = aws_subnet.public[*].id
}

output "public_subnet_arns" {
  description = "ARNs das subnets públicas"
  value       = aws_subnet.public[*].arn
}

output "public_subnet_cidrs" {
  description = "CIDR blocks das subnets públicas"
  value       = aws_subnet.public[*].cidr_block
}

output "public_subnet_availability_zones" {
  description = "Availability zones das subnets públicas"
  value       = aws_subnet.public[*].availability_zone
}

# Outputs do Internet Gateway
output "internet_gateway_id" {
  description = "ID do Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "internet_gateway_arn" {
  description = "ARN do Internet Gateway"
  value       = aws_internet_gateway.main.arn
}

# Outputs da Route Table Pública
output "public_route_table_id" {
  description = "ID da route table pública"
  value       = aws_route_table.public_internet_access.id
}

output "public_route_table_arn" {
  description = "ARN da route table pública"
  value       = aws_route_table.public_internet_access.arn
}

output "public_route_id" {
  description = "ID da rota pública para internet"
  value       = aws_route.public.id
}

output "public_route_table_association_ids" {
  description = "IDs das associações da route table pública"
  value       = aws_route_table_association.public[*].id
}

# Outputs das Private Subnets
output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = aws_subnet.private[*].id
}

output "private_subnet_arns" {
  description = "ARNs das subnets privadas"
  value       = aws_subnet.private[*].arn
}

output "private_subnet_cidrs" {
  description = "CIDR blocks das subnets privadas"
  value       = aws_subnet.private[*].cidr_block
}

output "private_subnet_availability_zones" {
  description = "Availability zones das subnets privadas"
  value       = aws_subnet.private[*].availability_zone
}

# Outputs dos NAT Gateways
output "nat_gateway_ids" {
  description = "IDs dos NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "IPs públicos dos NAT Gateways"
  value       = aws_nat_gateway.main[*].public_ip
}

output "elastic_ip_ids" {
  description = "IDs dos Elastic IPs"
  value       = aws_eip.eip[*].id
}

output "elastic_ip_addresses" {
  description = "Endereços dos Elastic IPs"
  value       = aws_eip.eip[*].public_ip
}

# Outputs das Route Tables Privadas
output "private_route_table_ids" {
  description = "IDs das route tables privadas"
  value       = aws_route_table.private[*].id
}

output "private_route_ids" {
  description = "IDs das rotas privadas para NAT Gateway"
  value       = aws_route.private[*].id
}

output "private_route_table_association_ids" {
  description = "IDs das associações das route tables privadas"
  value       = aws_route_table_association.private[*].id
}

# Outputs das Database Subnets
output "database_subnet_ids" {
  description = "IDs das subnets de banco de dados"
  value       = aws_subnet.database_subnets[*].id
}

output "database_subnet_arns" {
  description = "ARNs das subnets de banco de dados"
  value       = aws_subnet.database_subnets[*].arn
}

output "database_subnet_cidrs" {
  description = "CIDR blocks das subnets de banco de dados"
  value       = aws_subnet.database_subnets[*].cidr_block
}

output "database_subnet_availability_zones" {
  description = "Availability zones das subnets de banco de dados"
  value       = aws_subnet.database_subnets[*].availability_zone
}
