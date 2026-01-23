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

  # HTTP apenas do ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP do ALB"
  }

  # HTTPS apenas do ALB
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTPS do ALB"
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


# NOTA: Instância EC2 individual removida - substituída por Auto Scaling Group (Issue #7)
# A instância WordPress agora é gerenciada pelo ASG definido em asg.tf

# User data usando templatefile (método moderno)
locals {
  user_data = templatefile("${path.module}/user_data.tpl", {
    ssm_db_username_parameter = aws_ssm_parameter.db_username.name
    ssm_db_password_parameter = aws_ssm_parameter.db_password.name
    ssm_db_endpoint_parameter = aws_ssm_parameter.db_endpoint.name
    aws_region                = var.aws_region
    db_name                   = "wordpress"
    efs_dns_name              = aws_efs_file_system.wordpress.dns_name
    efs_access_point_id       = aws_efs_access_point.wordpress.id
  })
}
