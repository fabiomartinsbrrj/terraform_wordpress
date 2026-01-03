resource "aws_subnet" "database_subnets" {
  count = length(var.database_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnets[count.index].cidr
  availability_zone = var.database_subnets[count.index].availability_zone

  tags = {
    Name = var.database_subnets[count.index].name
  }

  depends_on = [
    aws_vpc_ipv4_cidr_block_association.main
  ]
}

# permito o trafego de saída para todo lugar 
resource "aws_network_acl" "database" {
  vpc_id = aws_vpc.main.id

  egress {
    rule_no    = 200
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = format("%s-databases", var.project_name)
  }
}

# nego o trafego de entrada para todo lugar
resource "aws_network_acl_rule" "deny" {
  network_acl_id = aws_network_acl.database.id
  rule_action    = "deny"
  rule_number    = 300

  protocol   = "-1"
  cidr_block = "0.0.0.0/0"
  from_port  = 0
  to_port    = 0
}

# liberar a porta 3306 para o mysql
resource "aws_network_acl_rule" "allow_3306" {
  count = length(var.private_subnets)

  network_acl_id = aws_network_acl.database.id
  rule_action    = "allow"
  rule_number    = 10 + count.index

  egress = false

  protocol   = "tcp"
  cidr_block = aws_subnet.private[count.index].cidr_block
  from_port  = 3306
  to_port    = 3306
}

#exemplo de liberar a porta 6379 para o redis
resource "aws_network_acl_rule" "allow_6379" {
  count = length(var.private_subnets)

  network_acl_id = aws_network_acl.database.id
  rule_action    = "allow"
  rule_number    = 20 + count.index

  egress = false

  protocol   = "tcp"
  cidr_block = aws_subnet.private[count.index].cidr_block
  from_port  = 6379
  to_port    = 6379
}

# para valer preciso de um subnet association
resource "aws_network_acl_association" "database" {
  count = length(var.database_subnets)

  subnet_id      = aws_subnet.database_subnets[count.index].id
  network_acl_id = aws_network_acl.database.id
}
