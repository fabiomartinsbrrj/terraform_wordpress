# Roadmap — Terraform WordPress Infrastructure

Acompanhamento das issues do projeto. Issues abertas: [github.com/fabiomartinsbrrj/terraform_wordpress/issues](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues)

---

## ✅ Concluído

| Issue | Título | Branch / PR |
|-------|--------|-------------|
| [#1](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/1) | IAM Role SSM para instâncias WordPress | `iam.tf` |
| [#2](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/2) | EFS para compartilhamento de arquivos WordPress | PR [#21](https://github.com/fabiomartinsbrrj/terraform_wordpress/pull/21) |
| [#3](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/3) | Security Groups para ALB e WordPress | `ec2.tf` |
| [#4](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/4) | RDS MySQL para banco de dados WordPress | PR [#11](https://github.com/fabiomartinsbrrj/terraform_wordpress/pull/11) |
| [#5](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/5) | Launch Template para instâncias WordPress | `asg.tf` |
| [#6](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/6) | Application Load Balancer na subnet pública | PR [#14](https://github.com/fabiomartinsbrrj/terraform_wordpress/pull/14) |
| [#7](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/7) | Auto Scaling Group na subnet privada | PR [#19](https://github.com/fabiomartinsbrrj/terraform_wordpress/pull/19) |
| [#15](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/15) | Route 53 DNS personalizado | PR [#18](https://github.com/fabiomartinsbrrj/terraform_wordpress/pull/18) |
| — | Fix: EFS session sharing (sessões PHP compartilhadas) | PR [#23](https://github.com/fabiomartinsbrrj/terraform_wordpress/pull/23) |

---

## 📋 Planejado

### Alta prioridade

| Issue | Título | Labels |
|-------|--------|--------|
| [#13](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/13) | HTTPS no ALB com certificado SSL/TLS (ACM) | `security`, `alb`, `https` |
| [#12](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/12) | Atualizar PHP 7.4 → 8.3 | `security`, `enhancement` |
| [#17](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/17) | CloudWatch para monitoramento completo | `monitoring`, `observability` |
| [#16](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/16) | AWS WAF para proteção contra ataques web | `security`, `waf` |

### Baixa prioridade

| Issue | Título | Labels |
|-------|--------|--------|
| [#20](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/20) | Replicação Cross-Region para EFS | `efs`, `disaster-recovery` |

---

> Nota: #16 e #22 são duplicatas — manter apenas #16.
