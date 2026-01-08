# ==============================================================================
# Auto Scaling Group Resources - Issue #7
# ==============================================================================

# ==============================================================================
# FASE 1: Launch Template
# ==============================================================================

# FASE 1.1: Launch Template para instâncias WordPress
# Define configuração padrão para todas as instâncias do ASG
resource "aws_launch_template" "wordpress" {
  name_prefix   = "${var.project_name}-wordpress-"
  description   = "Launch template para instancias WordPress do ASG"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  # Security Groups
  vpc_security_group_ids = [aws_security_group.wordpress_basic.id]

  # IAM Instance Profile para SSM
  iam_instance_profile {
    name = aws_iam_instance_profile.wordpress_ssm.name
  }

  # User Data - reutiliza template existente
  user_data = base64encode(local.user_data)

  # EBS Configuration - mesmo padrão da instância atual
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  # EBS Optimized
  ebs_optimized = true

  # Monitoring detalhado para CloudWatch
  monitoring {
    enabled = true
  }

  # Key pair para troubleshooting (opcional)
  # key_name = var.key_pair_name

  tags = {
    Name = "${var.project_name}-launch-template"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-asg-instance"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "ASG"
    }
  }
}

# ==============================================================================
# FASE 2: Auto Scaling Group
# ==============================================================================

# FASE 2.1: Auto Scaling Group principal
# Gerencia instâncias WordPress em subnets privadas com integração ALB
resource "aws_autoscaling_group" "wordpress" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.wordpress.arn]

  # Configuração de capacidade
  min_size         = 1
  max_size         = 3
  desired_capacity = 2

  # Health checks
  health_check_type         = "ELB" # ELB + EC2 health checks
  health_check_grace_period = 300   # 5 minutos para inicialização

  # Launch Template
  launch_template {
    id      = aws_launch_template.wordpress.id
    version = "$Latest"
  }

  # Estratégia de terminação
  termination_policies = ["OldestInstance"]

  # Proteção contra scale-in acidental
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  # Tags propagadas para instâncias
  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "AutoScaling"
    propagate_at_launch = true
  }

  # Lifecycle hooks para graceful shutdown (opcional)
  # initial_lifecycle_hook {
  #   name                 = "wordpress-shutdown-hook"
  #   default_result       = "ABANDON"
  #   heartbeat_timeout    = 300
  #   lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
  # }
}

# ==============================================================================
# FASE 3: Scaling Policies
# ==============================================================================

# FASE 3.1: Scale Up Policy - Adiciona 1 instância
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.wordpress.name
  policy_type            = "SimpleScaling"

}

# FASE 3.2: Scale Down Policy - Remove 1 instância
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.wordpress.name
  policy_type            = "SimpleScaling"

}

# ==============================================================================
# FASE 4: CloudWatch Alarms
# ==============================================================================

# FASE 4.1: CloudWatch Alarm - CPU High (>70%)
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120" # 2 minutos
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors ec2 cpu utilization for scale up"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wordpress.name
  }

  tags = {
    Name = "${var.project_name}-cpu-high-alarm"
  }
}

# FASE 4.2: CloudWatch Alarm - CPU Low (<30%)
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120" # 2 minutos
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "This metric monitors ec2 cpu utilization for scale down"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wordpress.name
  }

  tags = {
    Name = "${var.project_name}-cpu-low-alarm"
  }
}
