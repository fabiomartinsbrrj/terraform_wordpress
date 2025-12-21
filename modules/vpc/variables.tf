variable "vpc_cidr" {
  description = "CIDR block para a VPC"
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
