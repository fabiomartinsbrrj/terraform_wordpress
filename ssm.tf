# SSM Parameters para credenciais do RDS MySQL
resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.project_name}/rds/username"
  type  = "String"
  value = var.db_username

  tags = {
    Name        = "${var.project_name}-db-username"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/rds/password"
  type  = "SecureString"
  value = var.db_password

  tags = {
    Name        = "${var.project_name}-db-password"
    Environment = var.environment
  }
}

# Data sources para ler os SSM Parameters
data "aws_ssm_parameter" "db_username" {
  name       = aws_ssm_parameter.db_username.name
  depends_on = [aws_ssm_parameter.db_username]
}

data "aws_ssm_parameter" "db_password" {
  name            = aws_ssm_parameter.db_password.name
  with_decryption = true
  depends_on      = [aws_ssm_parameter.db_password]
}
