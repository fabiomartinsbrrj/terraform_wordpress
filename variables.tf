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

variable "vpc_cidr" {
  type        = string
  description = "CIDR principal da VPC"
}

variable "vpc_additional_cidrs" {
  type        = list(string)
  description = "Lista de CIDRS adicionais da VPC"
  default     = []
}

variable "public_subnets" {
  description = "Lista de Public Subnets da VPC"
  type = list(object({
    name              = string
    cidr              = string
    availability_zone = string
  }))
}


variable "private_subnets" {
  description = "Lista de Private Subnets da VPC"
  type = list(object({
    name              = string
    cidr              = string
    availability_zone = string
  }))
}

/*
variable "database_subnets" {
  description = "Lista de Databases Subnets da VPC"
  default     = []
  type = list(object({
    name              = string
    cidr              = string
    availability_zone = string
  }))
}
*/
