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

# Instance Profile para a role SSM
resource "aws_iam_instance_profile" "wordpress_ssm" {
  name_prefix = "${var.project_name}-wordpress-ssm-"
  role        = aws_iam_role.wordpress_ssm.name

  tags = {
    Name = "${var.project_name}-wordpress-ssm-profile"
  }
}
