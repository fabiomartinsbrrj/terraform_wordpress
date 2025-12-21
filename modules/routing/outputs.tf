output "public_route_table_id" {
  description = "ID da route table pública"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID da route table privada"
  value       = aws_route_table.private.id
}
