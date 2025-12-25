output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block da VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_additional_cidrs" {
  description = "Lista de CIDRS adicionais da VPC"
  value       = aws_vpc_ipv4_cidr_block_association.main[*].cidr_block
}

output "vpc_additional_cidr_association_ids" {
  description = "IDs das associações de CIDR adicionais (para depends_on)"
  value       = aws_vpc_ipv4_cidr_block_association.main[*].id
}
