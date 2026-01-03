resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.project_name
  }
}

/* recurso para associar CIDRs secundarios a VPC */
# https://docs.aws.amazon.com/vpc/latest/userguide/vpc-cidr-blocks.html#vpc-sizing-ipv4 Não podemos associar qualquer CIDR a VPC.
resource "aws_vpc_ipv4_cidr_block_association" "main" {
  count = length(var.vpc_additional_cidrs)

  vpc_id     = aws_vpc.main.id
  cidr_block = var.vpc_additional_cidrs[count.index]
}