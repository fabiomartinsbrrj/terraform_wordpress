variable "vpc_id" {
  description = "ID da VPC onde os gateways serão criados"
  type        = string
}

variable "public_subnet_id" {
  description = "ID da subnet pública onde o NAT Gateway será criado"
  type        = string
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
