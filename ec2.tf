# ==============================================================================
# EC2 Resources para WordPress
# ==============================================================================

# Data source para AMI Amazon Linux 2 mais recente
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group básico para WordPress
resource "aws_security_group" "wordpress_basic" {
  name_prefix = "${var.project_name}-wordpress-basic-"
  vpc_id      = aws_vpc.main.id
  description = "Security group basico para instancia WordPress"

  # HTTP apenas da VPC (ALB)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTP da VPC"
  }

  # HTTPS apenas da VPC (ALB)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS da VPC"
  }

  # SSH para troubleshooting
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "SSH interno da VPC"
  }

  # MySQL/RDS (para RDS futuro)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "MySQL para RDS"
  }

  # EFS/NFS (para EFS futuro)
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "NFS para EFS"
  }

  # Egress - saída para internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Saida para internet"
  }

  tags = {
    Name = "${var.project_name}-wordpress-basic-sg"
  }
}


# Instância EC2 WordPress básica
resource "aws_instance" "wordpress" {
  ami                    = data.aws_ami.amazon_linux.id
  user_data_base64       = base64encode(local.user_data)
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id # Subnet privada (correto)
  vpc_security_group_ids = [aws_security_group.wordpress_basic.id]
  iam_instance_profile   = aws_iam_instance_profile.wordpress_ssm.name

  # Sem IP público (subnet privada)
  associate_public_ip_address = false

  # EBS otimizado
  ebs_optimized = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }



  tags = {
    Name = "${var.project_name}-wordpress-basic"
  }
}

# User data usando templatefile (método moderno)
locals {
  user_data = templatefile("${path.module}/user_data.tpl", {
    ssm_db_username_parameter = aws_ssm_parameter.db_username.name
    ssm_db_password_parameter = aws_ssm_parameter.db_password.name
    ssm_db_endpoint_parameter = aws_ssm_parameter.db_endpoint.name
    aws_region                = var.aws_region
    db_name                   = "wordpress"
  })
}
