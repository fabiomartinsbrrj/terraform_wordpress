# 🎯 Plano de Execução - Issue #6: Application Load Balancer

**Issue**: [#6 - Criar Application Load Balancer na subnet pública](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/6)  
**Branch**: `feature/issue-6-alb`  
**Data**: Janeiro 2026  

## 📋 **Objetivo**

Implementar Application Load Balancer para distribuir tráfego HTTP/HTTPS para as instâncias WordPress nas subnets privadas.

## 🎯 **Escopo da Implementação**

### ✅ **O que será implementado:**

- ALB nas subnets públicas (internet-facing)
- Security group específico para ALB
- Target group para instâncias WordPress
- Listeners HTTP (80) e HTTPS (443)
- Health checks configurados
- Outputs para DNS do ALB
- Validação via Makefile

### ❌ **O que NÃO está no escopo:**

- Certificados SSL reais (ACM)
- Auto Scaling Groups
- WAF (Web Application Firewall)
- CloudFront CDN

## 📋 **Fase 1: Preparação e Security Groups** (Prioridade Alta)

### **1.1 Security Group para ALB**

- **Arquivo**: `alb.tf` (novo)
- **Nome**: `${var.project_name}-alb-sg`
- **Regras de entrada**:
  - HTTP (80) de `0.0.0.0/0` - "HTTP from internet"
  - HTTPS (443) de `0.0.0.0/0` - "HTTPS from internet"
- **Regras de saída**:
  - HTTP (80) para VPC CIDR - "HTTP to WordPress instances"
  - HTTPS (443) para VPC CIDR - "HTTPS to WordPress instances"

### **1.2 Atualizar Security Group WordPress**

- **Arquivo**: `ec2.tf`
- **Modificação**: Alterar regras HTTP/HTTPS
- **Antes**: `cidr_blocks = [var.vpc_cidr]`
- **Depois**: `security_groups = [aws_security_group.alb.id]`
- **Objetivo**: Aceitar tráfego apenas do ALB

## 📋 **Fase 2: Implementação do ALB** (Prioridade Alta)

### **2.1 Application Load Balancer**

```hcl
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
```

### **2.2 Target Group**

```hcl
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
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}
```

### **2.3 Target Group Attachment**

```hcl
resource "aws_lb_target_group_attachment" "wordpress" {
  target_group_arn = aws_lb_target_group.wordpress.arn
  target_id        = aws_instance.wordpress.id
  port             = 80
}
```

## 📋 **Fase 3: Listeners e Roteamento** (Prioridade Alta/Média)

### **3.1 Listener HTTP (Porta 80)**

```hcl
resource "aws_lb_listener" "wordpress_http" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}
```

### **3.2 Listener HTTPS (Porta 443)** - *Opcional para MVP*

```hcl
resource "aws_lb_listener" "wordpress_https" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "arn:aws:acm:region:account:certificate/certificate-id"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}
```

## 📋 **Fase 4: Outputs e Documentação** (Prioridade Média/Baixa)

### **4.1 Outputs no arquivo outputs.tf**

```hcl
# ==============================================================================
# ALB Outputs
# ==============================================================================

output "alb_dns_name" {
  description = "DNS name do Application Load Balancer"
  value       = aws_lb.wordpress.dns_name
}

output "alb_arn" {
  description = "ARN do Application Load Balancer"
  value       = aws_lb.wordpress.arn
}

output "alb_zone_id" {
  description = "Zone ID do Application Load Balancer"
  value       = aws_lb.wordpress.zone_id
}

output "target_group_arn" {
  description = "ARN do Target Group WordPress"
  value       = aws_lb_target_group.wordpress.arn
}

output "alb_security_group_id" {
  description = "ID do Security Group do ALB"
  value       = aws_security_group.alb.id
}
```

### **4.2 Validação no Makefile**

```makefile
validate-alb: ## Testa conectividade através do ALB
 @echo "🔍 Validando Application Load Balancer..."
 @if [ ! -f $(SCRIPTS_DIR)/validate_alb_access.sh ]; then \
  echo "❌ Script validate_alb_access.sh não encontrado!"; \
  exit 1; \
 fi
 @chmod +x $(SCRIPTS_DIR)/validate_alb_access.sh
 @$(SCRIPTS_DIR)/validate_alb_access.sh
```

## 🔄 **Ordem de Execução Recomendada**

1. ✅ **Criar arquivo `alb.tf`** com security group
2. ✅ **Implementar ALB** e target group  
3. ✅ **Configurar listener HTTP**
4. ✅ **Registrar instância** no target group
5. ✅ **Atualizar security group** WordPress
6. ✅ **Adicionar outputs**
7. ✅ **Testar conectividade**
8. 🔄 **Implementar HTTPS** (opcional)
9. 📝 **Documentar** no README

## ⚠️ **Considerações Importantes**

### **Dependências**

- ALB precisa de pelo menos 2 subnets públicas em AZs diferentes
- WordPress deve estar rodando e respondendo na porta 80
- Security groups devem permitir comunicação ALB → WordPress

### **Limitações Atuais**

- Apenas 1 instância WordPress (sem Auto Scaling)
- Sem certificado SSL real
- Sem session persistence (sticky sessions)
- Sem shared storage entre instâncias

### **Requisitos de Rede**

- Subnets públicas: `aws_subnet.public[*].id`
- VPC: `aws_vpc.main.id`
- Internet Gateway: Deve estar funcionando

## 🧪 **Critérios de Teste e Validação**

### **Testes Obrigatórios**

- [ ] ALB criado com status "active"
- [ ] Target group mostra instância "healthy"
- [ ] WordPress acessível via ALB DNS name
- [ ] Health checks passando (status 200)
- [ ] Security groups funcionando corretamente

### **Comandos de Teste**

```bash
# Testar ALB DNS
curl -I http://<ALB_DNS_NAME>

# Verificar target health
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>

# Testar via Makefile
make validate-alb
```

## 📊 **Métricas de Sucesso**

- **Disponibilidade**: WordPress acessível via ALB 99%+ do tempo
- **Health Check**: Latência < 5s, success rate > 95%
- **Security**: Instância WordPress não acessível diretamente
- **Performance**: Response time através do ALB < 2s

## 🔗 **Recursos Relacionados**

- **Issue #1**: Session Manager (dependência para troubleshooting)
- **Issue #4**: RDS MySQL (dependência para WordPress funcionar)
- **Issue #7**: Auto Scaling (próximo passo após ALB)
- **Issue #8**: CloudFront (CDN para performance)

## 📝 **Notas de Implementação**

- Usar naming convention: `${var.project_name}-<resource>`
- Tags obrigatórias em todos os recursos
- Seguir princípio de least privilege nos security groups
- Documentar todas as mudanças no CHANGELOG.md
