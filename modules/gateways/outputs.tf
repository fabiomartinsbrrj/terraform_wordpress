output "internet_gateway_id" {
  description = "ID do Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID do NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "IP público do NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "elastic_ip_id" {
  description = "ID do Elastic IP"
  value       = aws_eip.nat.id
}
