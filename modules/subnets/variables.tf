variable "vpc_id" {
  description = "ID da VPC onde as subnets serão criadas"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block para a subnet pública"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "Lista de CIDR blocks para as subnets privadas"
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
