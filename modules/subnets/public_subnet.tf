resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id = var.vpc_id

  cidr_block        = var.public_subnets[count.index].cidr
  availability_zone = var.public_subnets[count.index].availability_zone

  depends_on = [
    null_resource.wait_for_additional_cidrs
  ]

  tags = merge(var.common_tags, {
    Name = var.public_subnets[count.index].name
    Type = "Public"
  })
}

resource "aws_route_table" "public_internet_access" {
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.project_name}-public-access"
  }
}

//tudo que for trafego externo encaminhar para o aws_internet_gateway.main
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public_internet_access.id
  destination_cidr_block = "0.0.0.0/0"

  gateway_id = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id = aws_subnet.public[count.index].id

  route_table_id = aws_route_table.public_internet_access.id
}
