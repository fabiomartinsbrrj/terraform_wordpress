# Configuração do provider AWS
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Tags comuns para todos os recursos
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Módulo VPC
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  vpc_additional_cidrs = var.vpc_additional_cidrs
  project_name         = var.project_name
  common_tags          = local.common_tags
}


# Módulo Subnets
module "public_subnets" {
  source = "./modules/subnets"

  vpc_id                              = module.vpc.vpc_id
  vpc_additional_cidr_association_ids = module.vpc.vpc_additional_cidr_association_ids
  public_subnets                      = var.public_subnets
  /*private_subnet_cidrs = var.private_subnet_cidrs*/
  project_name = var.project_name
  common_tags  = local.common_tags
}

/*

# Módulo Gateways
module "gateways" {
  source = "./modules/gateways"

  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.subnets.public_subnet_id
  project_name     = var.project_name
  common_tags      = local.common_tags
}

# Módulo Routing
module "routing" {
  source = "./modules/routing"

  vpc_id              = module.vpc.vpc_id
  internet_gateway_id = module.gateways.internet_gateway_id
  nat_gateway_id      = module.gateways.nat_gateway_id
  public_subnet_id    = module.subnets.public_subnet_id
  private_subnet_ids  = module.subnets.private_subnet_ids
  project_name        = var.project_name
  common_tags         = local.common_tags
}
*/
