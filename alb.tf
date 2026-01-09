# ==============================================================================
# Application Load Balancer Resources - Issue #6
# ==============================================================================

# FASE 1.1: Security Group para Application Load Balancer
# Permite tráfego HTTP/HTTPS da internet e encaminha para instâncias WordPress
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = aws_vpc.main.id
  description = "Security group para Application Load Balancer"

  # HTTP da internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  # HTTPS da internet
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  # HTTP para instâncias WordPress
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTP to WordPress instances"
  }

  # HTTPS para instâncias WordPress
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS to WordPress instances"
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ==============================================================================
# FASE 2: Implementação do ALB
# ==============================================================================

# FASE 2.1: Application Load Balancer
# Internet-facing ALB distribuído em 2 subnets públicas para alta disponibilidade
resource "aws_lb" "wordpress" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# FASE 2.2: Target Group para instâncias WordPress
# Define como o ALB encaminha tráfego e monitora saúde das instâncias
resource "aws_lb_target_group" "wordpress" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200,302" # Aceita 200 (OK) e 302 (Redirect) para WordPress setup
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "${var.project_name}-target-group"
  }
}

# NOTA: Target Group Attachment removido - ASG gerencia automaticamente (Issue #7)
# O Auto Scaling Group registra/desregistra instâncias automaticamente no target group

# ==============================================================================
# FASE 3: Listeners e Roteamento
# ==============================================================================

# FASE 3.1: Listener HTTP (porta 80)
# Recebe tráfego HTTP da internet e encaminha para target group WordPress
# NOTA: HTTPS (Fase 3.2) foi movido para Issue separada (requer certificado SSL)
resource "aws_lb_listener" "wordpress_http" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }

  tags = {
    Name = "${var.project_name}-http-listener"
  }
}
