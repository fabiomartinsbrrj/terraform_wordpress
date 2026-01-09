# ==============================================================================
# EFS (Elastic File System) para compartilhamento de arquivos WordPress
# Issue #2: Implementar EFS para compartilhamento de arquivos WordPress
# ==============================================================================

# CONCEITO: EFS permite compartilhamento de arquivos entre múltiplas instâncias EC2
# - Essencial para Auto Scaling Groups onde instâncias precisam acessar os mesmos arquivos
# - WordPress uploads, themes, plugins ficam sincronizados entre todas as instâncias
# - Performance escalável e backup automático

# FASE 1: Security Group para EFS - OBRIGATÓRIO
# Controla acesso ao sistema de arquivos via protocolo NFS (porta 2049)
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Security group para EFS - permite acesso NFS das instancias WordPress"
  vpc_id      = aws_vpc.main.id

  # INGRESS: Permite tráfego NFS (porta 2049) apenas das subnets privadas
  # Princípio de menor privilégio - só instâncias WordPress podem acessar
  ingress {
    description = "NFS from WordPress instances in private subnets"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    # Usando loop para incluir CIDRs de todas as subnets privadas
    cidr_blocks = [for subnet in var.private_subnets : subnet.cidr]
  }

  # EGRESS: Permite todo tráfego de saída (padrão para EFS)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-efs-sg"
    Environment = var.environment
    Purpose     = "EFS-NFS-Access"
    Issue       = "2"
  }
}

# FASE 2: EFS File System - OBRIGATÓRIO
# Sistema de arquivos compartilhado que escala automaticamente
resource "aws_efs_file_system" "wordpress" {
  # Token único para identificar o file system durante criação
  creation_token = "${var.project_name}-wordpress-efs"

  # PERFORMANCE MODE: General Purpose
  # - Menor latência (até 7000 ops/sec)
  # - Ideal para WordPress (muitas operações pequenas)
  # - Alternativa: Max I/O (maior throughput, maior latência)
  performance_mode = "generalPurpose"

  # THROUGHPUT MODE: Provisioned
  # - Controle preciso da performance (10 MiB/s inicial)
  # - Custo adicional mas performance garantida
  # - Alternativa: Bursting (gratuito, performance variável)
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = 10

  # ENCRYPTION: Habilitada em repouso - OBRIGATÓRIO para segurança
  # - Dados criptografados automaticamente
  # - Chave AWS KMS gerenciada pela AWS
  encrypted = true

  # LIFECYCLE POLICY: Otimização de custos
  # Arquivos não acessados por 30 dias vão para Infrequent Access (50% mais barato)
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  # Arquivos acessados voltam para Standard automaticamente
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name        = "${var.project_name}-wordpress-efs"
    Environment = var.environment
    Purpose     = "WordPress-Shared-Storage"
    Issue       = "2"
  }
}

# FASE 3: Mount Targets - OBRIGATÓRIO
# Pontos de acesso ao EFS em cada Availability Zone
# Necessário para instâncias EC2 acessarem o file system
resource "aws_efs_mount_target" "wordpress" {
  # Cria um mount target para cada subnet privada (multi-AZ)
  count = length(var.private_subnets)

  # Referência ao file system criado acima
  file_system_id = aws_efs_file_system.wordpress.id

  # Subnet onde o mount target será criado
  # Instâncias nesta subnet poderão acessar o EFS
  subnet_id = aws_subnet.private[count.index].id

  # Security group que controla acesso NFS
  security_groups = [aws_security_group.efs.id]
}

# FASE 3: Access Point - RECOMENDADO para WordPress
# Controla acesso e permissões de forma granular
resource "aws_efs_access_point" "wordpress" {
  file_system_id = aws_efs_file_system.wordpress.id

  # POSIX USER: Configurações de usuário/grupo
  # UID/GID 33 = www-data (usuário padrão do Apache/WordPress)
  posix_user {
    gid = 33 # www-data group ID
    uid = 33 # www-data user ID
  }

  # ROOT DIRECTORY: Diretório raiz do access point
  # Cria automaticamente /wordpress com permissões corretas
  root_directory {
    path = "/wordpress" # Caminho dentro do EFS
    creation_info {
      owner_gid   = 33    # Proprietário: www-data group
      owner_uid   = 33    # Proprietário: www-data user
      permissions = "755" # rwxr-xr-x (leitura/escrita para owner, leitura para outros)
    }
  }

  tags = {
    Name        = "${var.project_name}-wordpress-access-point"
    Environment = var.environment
    Purpose     = "WordPress-EFS-Access"
    Issue       = "2"
  }
}

# FASE 4: Backup Policy - OBRIGATÓRIO para produção
# Backup automático diário com retenção de 35 dias
resource "aws_efs_backup_policy" "wordpress" {
  file_system_id = aws_efs_file_system.wordpress.id

  backup_policy {
    # ENABLED: Backup automático diário
    # - Backup às 5:00 UTC
    # - Retenção: 35 dias
    # - Restauração point-in-time
    status = "ENABLED"
  }
}


# FASE 5: Outputs para EFS - OBRIGATÓRIO para integração
# Informações necessárias para outros recursos e validação
output "efs_file_system_id" {
  description = "ID do EFS file system"
  value       = aws_efs_file_system.wordpress.id
}

output "efs_file_system_arn" {
  description = "ARN do EFS file system"
  value       = aws_efs_file_system.wordpress.arn
}

output "efs_dns_name" {
  description = "DNS name do EFS para mount"
  value       = aws_efs_file_system.wordpress.dns_name
}

output "efs_mount_target_ids" {
  description = "IDs dos mount targets EFS"
  value       = aws_efs_mount_target.wordpress[*].id
}

output "efs_mount_target_dns_names" {
  description = "DNS names dos mount targets"
  value       = aws_efs_mount_target.wordpress[*].dns_name
}

output "efs_access_point_id" {
  description = "ID do access point WordPress"
  value       = aws_efs_access_point.wordpress.id
}

output "efs_access_point_arn" {
  description = "ARN do access point WordPress"
  value       = aws_efs_access_point.wordpress.arn
}

output "efs_security_group_id" {
  description = "ID do security group EFS"
  value       = aws_security_group.efs.id
}

# Comandos úteis para mount
output "efs_mount_command" {
  description = "Comando para montar EFS via DNS"
  value       = "sudo mount -t efs ${aws_efs_file_system.wordpress.dns_name}:/ /mnt/efs"
}

output "efs_mount_command_access_point" {
  description = "Comando para montar EFS via access point"
  value       = "sudo mount -t efs -o tls,accesspoint=${aws_efs_access_point.wordpress.id} ${aws_efs_file_system.wordpress.dns_name}:/ /var/www/html"
}
