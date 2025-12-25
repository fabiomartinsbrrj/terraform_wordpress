variable "vpc_id" {
  description = "ID da VPC onde as subnets serão criadas"
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
variable "public_subnets" {
  description = "Lista de Public Subnets da VPC"
  type = list(object({
    name              = string
    cidr              = string
    availability_zone = string
  }))
}

variable "vpc_additional_cidr_association_ids" {
  description = "IDs das associações de CIDR adicionais (para depends_on)"
  type        = list(string)
  default     = []
}


/*
variable "public_subnet_cidr" {
  description = "CIDR block para a subnet pública"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "Lista de CIDR blocks para as subnets privadas"
  type        = list(string)
}
*/
