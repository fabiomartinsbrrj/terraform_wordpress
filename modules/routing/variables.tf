variable "vpc_id" {
  description = "ID da VPC onde as route tables serão criadas"
  type        = string
}

variable "internet_gateway_id" {
  description = "ID do Internet Gateway"
  type        = string
}

variable "nat_gateway_id" {
  description = "ID do NAT Gateway"
  type        = string
}

variable "public_subnet_id" {
  description = "ID da subnet pública"
  type        = string
}

variable "private_subnet_ids" {
  description = "Lista de IDs das subnets privadas"
  type        = list(string)
}

variable "project_name" {
  description = "Nome do projeto para identificação dos recursos"
  type        = string
}

variable "common_tags" {
  description = "Tags comuns para todos os recursos"
  type        = map(string)
  default     = {}
}
