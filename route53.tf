# ==============================================================================
# Route 53 Resources - Issue #15
# Implementação de DNS personalizado para fabiodev.com
# ==============================================================================

# ==============================================================================
# FASE 1: Hosted Zone Configuration
# ==============================================================================

# Local para construir o domínio completo do WordPress
locals {
  wordpress_domain = "${var.wordpress_subdomain}.${var.root_domain_name}"
}

# Hosted Zone para o domínio principal fabiodev.com
# IMPORTANTE: Se registrar o domínio via Route 53, esta hosted zone será criada automaticamente
# Se usar registrador externo, esta hosted zone precisa ser criada manualmente
resource "aws_route53_zone" "main" {
  name    = var.root_domain_name
  comment = "Hosted zone para ${var.root_domain_name} - WordPress Infrastructure"

  tags = {
    Name        = "${var.project_name}-hosted-zone"
    Environment = var.environment
    Project     = var.project_name
    Domain      = var.root_domain_name
    ManagedBy   = "Terraform"
    Issue       = "15"
  }
}

# ==============================================================================
# FASE 2: DNS Records Configuration
# ==============================================================================

# Registro A (Alias) para wordpress.fabiodev.com apontando para o ALB
# Este é o registro principal que conecta seu domínio personalizado ao ALB
resource "aws_route53_record" "wordpress" {
  zone_id = aws_route53_zone.main.zone_id
  name    = local.wordpress_domain
  type    = "A"

  # Alias record aponta diretamente para o ALB (melhor que IP fixo)
  alias {
    name                   = aws_lb.wordpress.dns_name
    zone_id                = aws_lb.wordpress.zone_id
    evaluate_target_health = true
  }
}

# Registro CNAME para www.wordpress.fabiodev.com
# Permite que usuários acessem tanto wordpress.fabiodev.com quanto www.wordpress.fabiodev.com
resource "aws_route53_record" "wordpress_www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${local.wordpress_domain}"
  type    = "CNAME"
  ttl     = var.ttl_default
  records = [local.wordpress_domain]
}

# ==============================================================================
# FASE 3: Automação de Name Servers (Opcional)
# ==============================================================================

# Recurso para automatizar atualização de name servers do domínio registrado
# NOTA: Só funciona se o domínio foi registrado via AWS Route 53 Domains
resource "null_resource" "update_domain_nameservers" {
  count = var.auto_update_nameservers ? 1 : 0

  depends_on = [aws_route53_zone.main]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Atualizando name servers do domínio ${var.root_domain_name}..."
      aws route53domains update-domain-nameservers \
        --domain-name ${var.root_domain_name} \
        --nameservers ${join(" ", formatlist("Name=%s", aws_route53_zone.main.name_servers))} \
        --region us-east-1
      echo "Name servers atualizados com sucesso!"
    EOT
  }

  # Trigger para re-executar se name servers mudarem
  triggers = {
    name_servers = join(",", aws_route53_zone.main.name_servers)
    domain_name  = var.root_domain_name
  }
}

# ==============================================================================
# FASE 4: Health Checks e Monitoramento
# ==============================================================================

# Health Check para monitorar a saúde do WordPress
# Monitora se wordpress.fabiodev.com está respondendo corretamente
resource "aws_route53_health_check" "wordpress" {
  count = var.enable_health_checks ? 1 : 0

  fqdn                    = local.wordpress_domain
  port                    = 80
  type                    = "HTTP"
  resource_path           = "/"
  failure_threshold       = 3
  request_interval        = 30
  cloudwatch_alarm_region = var.aws_region
  cloudwatch_alarm_name   = "${var.project_name}-wordpress-health"

  tags = {
    Name        = "${var.project_name}-wordpress-health-check"
    Environment = var.environment
    Domain      = local.wordpress_domain
    ManagedBy   = "Terraform"
    Issue       = "15"
  }
}

# Health Check para www.wordpress.fabiodev.com
# Monitora se a versão www também está funcionando
resource "aws_route53_health_check" "wordpress_www" {
  count = var.enable_health_checks ? 1 : 0

  fqdn                    = "www.${local.wordpress_domain}"
  port                    = 80
  type                    = "HTTP"
  resource_path           = "/"
  failure_threshold       = 3
  request_interval        = 30
  cloudwatch_alarm_region = var.aws_region
  cloudwatch_alarm_name   = "${var.project_name}-wordpress-www-health"

  tags = {
    Name        = "${var.project_name}-wordpress-www-health-check"
    Environment = var.environment
    Domain      = "www.${local.wordpress_domain}"
    ManagedBy   = "Terraform"
    Issue       = "15"
  }
}

# ==============================================================================
# OUTPUTS COMPLETOS DA FASE 3
# ==============================================================================

# Name servers da hosted zone (necessários para configurar no registrador)
output "hosted_zone_name_servers" {
  description = "Name servers da hosted zone - Configure estes no seu registrador de domínio"
  value       = aws_route53_zone.main.name_servers
}

output "hosted_zone_id" {
  description = "ID da hosted zone do Route 53"
  value       = aws_route53_zone.main.zone_id
}

output "wordpress_domain" {
  description = "Domínio completo do WordPress configurado"
  value       = local.wordpress_domain
}

output "wordpress_www_domain" {
  description = "Domínio www do WordPress configurado"
  value       = "www.${local.wordpress_domain}"
}

output "wordpress_url" {
  description = "URL completa do WordPress (HTTP)"
  value       = "http://${local.wordpress_domain}"
}

output "wordpress_www_url" {
  description = "URL completa do WordPress www (HTTP)"
  value       = "http://www.${local.wordpress_domain}"
}

output "health_check_ids" {
  description = "IDs dos health checks criados"
  value = var.enable_health_checks ? {
    wordpress     = aws_route53_health_check.wordpress[0].id
    wordpress_www = aws_route53_health_check.wordpress_www[0].id
  } : {}
}

output "dns_configuration_summary" {
  description = "Resumo da configuração DNS implementada"
  value = {
    root_domain      = var.root_domain_name
    wordpress_domain = local.wordpress_domain
    www_domain       = "www.${local.wordpress_domain}"
    hosted_zone_id   = aws_route53_zone.main.zone_id
    health_checks    = var.enable_health_checks
    records_created  = ["A (Alias)", "CNAME"]
  }
}
