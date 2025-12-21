# Variáveis de configuração geral
variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de deployment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nome do projeto para identificação dos recursos"
  type        = string
  default     = "wordpress-infra"
}

# Variáveis de rede
variable "vpc_cidr" {
  description = "CIDR block para a VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block para a subnet pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidrs" {
  description = "Lista de CIDR blocks para as subnets privadas"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
}
