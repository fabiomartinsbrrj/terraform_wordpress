output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks das subnets públicas"
  value       = aws_subnet.public[*].cidr_block
}

output "availability_zones" {
  description = "Availability zones utilizadas"
  value       = aws_subnet.public[*].availability_zone
}

/*
output "public_subnet_id" {
  description = "ID da subnet pública"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "CIDR block da subnet pública"
  value       = aws_subnet.public.cidr_block
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "CIDR blocks das subnets privadas"
  value       = aws_subnet.private[*].cidr_block
}

output "availability_zones" {
  description = "Availability zones utilizadas"
  value       = data.aws_availability_zones.available.names
}
*/
