# ==============================================================================
# IAM Resources para WordPress EC2
# ==============================================================================

# IAM Role para Session Manager (SSM)
resource "aws_iam_role" "wordpress_ssm" {
  name_prefix = "${var.project_name}-wordpress-ssm-"

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
    Name = "${var.project_name}-wordpress-ssm-role"
  }
}

# Attach da política SSM à role
resource "aws_iam_role_policy_attachment" "wordpress_ssm" {
  role       = aws_iam_role.wordpress_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Política personalizada para acessar SSM Parameters do RDS
resource "aws_iam_role_policy" "wordpress_ssm_parameters" {
  name_prefix = "${var.project_name}-ssm-parameters-"
  role        = aws_iam_role.wordpress_ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          aws_ssm_parameter.db_username.arn,
          aws_ssm_parameter.db_password.arn
        ]
      }
    ]
  })
}

# Instance Profile para a role SSM
resource "aws_iam_instance_profile" "wordpress_ssm" {
  name_prefix = "${var.project_name}-wordpress-ssm-"
  role        = aws_iam_role.wordpress_ssm.name

  tags = {
    Name = "${var.project_name}-wordpress-ssm-profile"
  }
}
