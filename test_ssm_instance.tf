# IAM Role para Session Manager
resource "aws_iam_role" "ssm_role" {
  name = "${var.project_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ssm-role"
  }
}

# Attach da política gerenciada para SSM
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.project_name}-ssm-profile"
  role = aws_iam_role.ssm_role.name

  tags = {
    Name = "${var.project_name}-ssm-profile"
  }
}

# Security Group para instância de teste
resource "aws_security_group" "test_instance" {
  name        = "${var.project_name}-test-instance-sg"
  description = "Security group para instancia de teste SSM"
  vpc_id      = aws_vpc.main.id

  # Regras de saída para atualizações e SSM
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS para SSM e atualizacoes"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP para atualizacoes"
  }

  tags = {
    Name = "${var.project_name}-test-instance-sg"
  }
}

# Obter AMI mais recente do Amazon Linux 2
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Instância EC2 temporária para teste SSM
resource "aws_instance" "test_ssm" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.test_instance.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip_address = false

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Instalar ferramentas úteis
    yum install -y htop curl wget nano
    
    # Criar arquivo de teste
    echo "Instância de teste SSM - $(date)" > /home/ec2-user/teste_ssm.txt
    echo "Conectividade via NAT Gateway funcionando!" >> /home/ec2-user/teste_ssm.txt
    
    # Testar conectividade
    curl -s https://httpbin.org/ip > /home/ec2-user/ip_externo.txt
    
    chown ec2-user:ec2-user /home/ec2-user/*.txt
  EOF
  )

  tags = {
    Name    = "${var.project_name}-test-ssm"
    Purpose = "SSM-Test"
    Type    = "Temporary"
  }
}

# Outputs para facilitar o teste
output "test_instance_id" {
  description = "ID da instância de teste para SSM"
  value       = aws_instance.test_ssm.id
}

output "test_instance_private_ip" {
  description = "IP privado da instância de teste"
  value       = aws_instance.test_ssm.private_ip
}

output "ssm_connect_command" {
  description = "Comando para conectar via Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.test_ssm.id}"
}
