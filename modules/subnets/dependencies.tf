# Este recurso null_resource garante que as subnets só sejam criadas
# após os CIDR blocks adicionais estarem associados à VPC
resource "null_resource" "wait_for_additional_cidrs" {
  count = length(var.vpc_additional_cidr_association_ids) > 0 ? 1 : 0

  triggers = {
    cidr_associations = join(",", var.vpc_additional_cidr_association_ids)
  }
}
