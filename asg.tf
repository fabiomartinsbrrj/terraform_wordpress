# ==============================================================================
# Auto Scaling Group Resources - Issue #7
# Implementação faseada de Auto Scaling Group para WordPress
# ==============================================================================

# CONCEITO: Auto Scaling Group (ASG) gerencia automaticamente instâncias EC2
# - Escalabilidade automática baseada em métricas (CPU, memória, etc.)
# - Alta disponibilidade através de múltiplas AZs
# - Self-healing: substitui instâncias não saudáveis automaticamente
# - Integração com ALB para distribuição de tráfego

# ==============================================================================
# FASE 1: Launch Template - OBRIGATÓRIO
# Define o "molde" para criação de novas instâncias no ASG
# ==============================================================================

# FASE 1.1: Launch Template para instâncias WordPress
# CONCEITO: Launch Template é como um "blueprint" que define:
# - Qual AMI usar, tipo de instância, security groups
# - Configurações de storage, networking, user data
# - Tags que serão aplicadas às instâncias criadas
resource "aws_launch_template" "wordpress" {
  name_prefix   = "${var.project_name}-wordpress-"
  description   = "Launch template para instancias WordPress do ASG"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  # SECURITY GROUPS: Reutiliza security group existente do WordPress
  # - Permite HTTP/HTTPS apenas do ALB (princípio de menor privilégio)
  # - Permite NFS (porta 2049) para acesso ao EFS
  # - SSH interno da VPC para troubleshooting
  vpc_security_group_ids = [aws_security_group.wordpress_basic.id]

  # IAM INSTANCE PROFILE: Permite acesso via Session Manager (SSM)
  # - Elimina necessidade de SSH direto
  # - Auditoria completa de acesso
  # - Integração com AWS Systems Manager
  iam_instance_profile {
    name = aws_iam_instance_profile.wordpress_ssm.name
  }

  # USER DATA: Script de inicialização reutilizado
  # - Instala WordPress, Apache, PHP
  # - Configura conexão com RDS MySQL
  # - Monta EFS para compartilhamento de arquivos
  user_data = base64encode(local.user_data)

  # EBS CONFIGURATION: Storage otimizado para WordPress
  # - GP3: Melhor performance/custo que GP2
  # - 20GB: Suficiente para SO + WordPress (arquivos no EFS)
  # - Encrypted: Segurança em repouso obrigatória
  # - Delete on termination: Evita volumes órfãos
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3" # 3000 IOPS baseline, melhor que GP2
      delete_on_termination = true  # Cleanup automático
      encrypted             = true  # Compliance e segurança
    }
  }

  # EBS OPTIMIZED: Melhora performance de I/O
  # - Dedicates bandwidth para EBS traffic
  # - Reduz latência de storage
  ebs_optimized = true

  # DETAILED MONITORING: Métricas CloudWatch em 1 minuto
  # - Permite scaling mais responsivo
  # - Melhor observabilidade da performance
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
# FASE 2: Auto Scaling Group - OBRIGATÓRIO
# Gerencia o ciclo de vida das instâncias WordPress
# ==============================================================================

# FASE 2.1: Auto Scaling Group principal
# CONCEITO: ASG é o "cérebro" que decide quando criar/destruir instâncias
# - Monitora health das instâncias via ELB + EC2 checks
# - Distribui instâncias em múltiplas AZs para HA
# - Integra com ALB para registro automático de targets
# - Responde a políticas de scaling baseadas em métricas
resource "aws_autoscaling_group" "wordpress" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.wordpress.arn]

  # CONFIGURAÇÃO DE CAPACIDADE: Balanceio entre disponibilidade e custo
  # - Min 1: Sempre pelo menos uma instância rodando
  # - Max 3: Controle de custos, evita scaling descontrolado
  # - Desired 2: Redundância para alta disponibilidade
  min_size         = 1
  max_size         = 3
  desired_capacity = 2

  # HEALTH CHECKS: Verificação dupla de saúde das instâncias
  # - ELB: Verifica se instância responde HTTP (health check do ALB)
  # - EC2: Verifica se instância está rodando (AWS hypervisor)
  # - Grace period: Tempo para WordPress inicializar completamente
  health_check_type         = "ELB" # Mais rigoroso que só EC2
  health_check_grace_period = 300   # 5 minutos para boot + WordPress setup

  # Launch Template
  launch_template {
    id      = aws_launch_template.wordpress.id
    version = "$Latest"
  }

  # ESTRATÉGIA DE TERMINAÇÃO: Como escolher qual instância remover
  # - OldestInstance: Remove instância mais antiga primeiro
  # - Alternativas: OldestLaunchTemplate, ClosestToNextInstanceHour
  # - Útil para rolling updates e otimização de custos
  termination_policies = ["OldestInstance"]

  # MÉTRICAS HABILITADAS: Observabilidade do ASG no CloudWatch
  # - Permite monitorar comportamento do scaling
  # - Essencial para debugging de políticas
  # - Dados para dashboards e alertas
  enabled_metrics = [
    "GroupMinSize",            # Capacidade mínima configurada
    "GroupMaxSize",            # Capacidade máxima configurada
    "GroupDesiredCapacity",    # Capacidade desejada atual
    "GroupInServiceInstances", # Instâncias healthy e servindo tráfego
    "GroupTotalInstances"      # Total de instâncias (incluindo launching/terminating)
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
# FASE 3: Scaling Policies - OBRIGATÓRIO
# Define COMO o ASG deve escalar (quantas instâncias adicionar/remover)
# ==============================================================================

# FASE 3.1: Scale Up Policy - Adiciona 1 instância
# CONCEITO: Política de scaling define a ação quando alarm é triggered
# - SimpleScaling: Adiciona/remove número fixo de instâncias
# - ChangeInCapacity: Muda capacidade em número absoluto
# - Cooldown: Evita scaling muito frequente (thrashing)
resource "aws_autoscaling_policy" "scale_up" {
  name = "${var.project_name}-scale-up"

  # SCALING ADJUSTMENT: Quantas instâncias adicionar
  # - Valor 1: Adiciona uma instância por vez (scaling conservador)
  # - Evita over-provisioning desnecessário
  scaling_adjustment = 1

  # ADJUSTMENT TYPE: Como interpretar o scaling_adjustment
  # - ChangeInCapacity: Adiciona/remove número exato de instâncias
  # - PercentChangeInCapacity: Baseado em porcentagem
  # - ExactCapacity: Define capacidade absoluta
  adjustment_type = "ChangeInCapacity"

  # COOLDOWN: Período de "resfriamento" após scaling
  # - 300s = 5 minutos para instância inicializar
  # - Evita scaling em cascata desnecessário
  cooldown = 300

  autoscaling_group_name = aws_autoscaling_group.wordpress.name
  policy_type            = "SimpleScaling" # Mais simples que StepScaling
}

# FASE 3.2: Scale Down Policy - Remove 1 instância
# CONCEITO: Scale down deve ser mais conservador que scale up
# - Perder capacidade é pior que ter capacidade extra
# - Mesmo cooldown para evitar oscillation
resource "aws_autoscaling_policy" "scale_down" {
  name = "${var.project_name}-scale-down"

  # SCALING ADJUSTMENT: Valor negativo remove instâncias
  # - Valor -1: Remove uma instância por vez
  # - Scaling conservador para evitar impacto no serviço
  scaling_adjustment = -1

  adjustment_type = "ChangeInCapacity"

  # COOLDOWN: Mesmo período para scale down
  # - Permite que carga se redistribua entre instâncias restantes
  # - Evita scale down muito agressivo
  cooldown = 300

  autoscaling_group_name = aws_autoscaling_group.wordpress.name
  policy_type            = "SimpleScaling"
}

# ==============================================================================
# FASE 4: CloudWatch Alarms - OBRIGATÓRIO
# Define QUANDO o ASG deve escalar (triggers baseados em métricas)
# ==============================================================================

# FASE 4.1: CloudWatch Alarm - CPU High (>70%)
# CONCEITO: Alarms monitoram métricas e triggeram ações
# - Threshold: Valor limite que dispara o alarm
# - Evaluation periods: Quantos períodos consecutivos acima do threshold
# - Period: Duração de cada período de avaliação
# - Statistic: Como agregar dados (Average, Maximum, Sum, etc.)
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name = "${var.project_name}-cpu-high"

  # COMPARISON OPERATOR: Como comparar métrica com threshold
  comparison_operator = "GreaterThanThreshold"

  # EVALUATION PERIODS: Quantos períodos consecutivos para trigger
  # - 2 períodos: Evita false positives de picos momentâneos
  # - Garante que alta CPU é sustentada, não esporádica
  evaluation_periods = "2"

  # MÉTRICA MONITORADA: CPU utilization agregada do ASG
  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"

  # PERIOD: Duração de cada período de avaliação
  # - 120s = 2 minutos: Balanceio entre responsividade e estabilidade
  # - Períodos muito curtos causam scaling nervoso
  period = "120"

  # STATISTIC: Como agregar dados dentro do período
  # - Average: Média de CPU de todas as instâncias do ASG
  # - Mais estável que Maximum, menos que Minimum
  statistic = "Average"

  # THRESHOLD: Limite de CPU que indica necessidade de scaling
  # - 70%: Conservador, deixa margem antes de saturação
  # - Permite tempo para nova instância inicializar
  threshold = "70"

  alarm_description = "Triggers scale up when average CPU > 70% for 4 minutes"

  # ACTION: Qual política executar quando alarm é triggered
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wordpress.name
  }

  tags = {
    Name = "${var.project_name}-cpu-high-alarm"
  }
}

# FASE 4.2: CloudWatch Alarm - CPU Low (<30%)
# CONCEITO: Scale down deve ser mais conservador que scale up
# - Threshold mais baixo (30% vs 70%)
# - Mesmo evaluation period para consistência
# - Evita oscillation entre scale up/down
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name = "${var.project_name}-cpu-low"

  comparison_operator = "LessThanThreshold"

  # EVALUATION PERIODS: Mesmo que scale up para consistência
  # - Garante que baixa CPU é sustentada
  # - Evita scale down prematuro durante picos temporários
  evaluation_periods = "2"

  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  period      = "120" # Mesmo período que scale up
  statistic   = "Average"

  # THRESHOLD: Limite baixo indica capacidade ociosa
  # - 30%: Conservador, garante que há realmente capacidade extra
  # - Gap de 40% entre scale up (70%) e scale down (30%)
  # - Evita thrashing (scaling up/down constante)
  threshold = "30"

  alarm_description = "Triggers scale down when average CPU < 30% for 4 minutes"

  # ACTION: Política de scale down
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wordpress.name
  }

  tags = {
    Name = "${var.project_name}-cpu-low-alarm"
  }
}
