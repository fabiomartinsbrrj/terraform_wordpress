# DB Subnet Group para RDS
# NOTA: Para destroy seguro, use o script: ./scripts/safe_destroy.sh
# Isso evita o erro: "Cannot delete the subnet group because at least one database instance is still using it"
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.database_subnets[*].id

  tags = {
    Name        = "${var.project_name} DB subnet group"
    Environment = var.environment
  }

  # Garantir que seja destruído após a instância RDS
  lifecycle {
    create_before_destroy = true
  }

}

# Security Group para RDS MySQL
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  description = "Security group for RDS MySQL database"
  vpc_id      = aws_vpc.main.id

  # Permitir conexões MySQL apenas do EC2 WordPress
  ingress {
    description     = "MySQL from WordPress EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_basic.id]
  }

  # Permitir saída para atualizações (stateful)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "wordpress" {
  identifier = "${var.project_name}-mysql"

  # Engine Configuration
  engine         = "mysql"
  engine_version = "8.0.44"
  instance_class = "db.t3.micro"

  # Storage Configuration
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database Configuration
  db_name  = "wordpress"
  username = data.aws_ssm_parameter.db_username.value
  password = data.aws_ssm_parameter.db_password.value

  # Network Configuration
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false

  # Backup Configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # High Availability (desabilitado para usar apenas uma subnet)
  multi_az = false

  # Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Performance Insights (não suportado em db.t3.micro)
  performance_insights_enabled = false

  # Deletion Protection (desabilitado para facilitar destroy em desenvolvimento)
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "${var.project_name}-mysql"
    Environment = var.environment
  }

  depends_on = [
    aws_db_subnet_group.main,
    aws_security_group.rds,
    aws_ssm_parameter.db_username,
    aws_ssm_parameter.db_password,
    aws_iam_role.rds_monitoring
  ]
}

# IAM Role para Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-rds-monitoring-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
