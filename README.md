# Infraestrutura AWS com Terraform - WordPress

Este projeto implementa uma infraestrutura completa na AWS para hospedar WordPress de forma escalável e segura. A arquitetura utiliza subnets privadas para as instâncias WordPress, com acesso via Session Manager, conectividade à internet através de NAT Gateway e **DNS personalizado via Route 53** para acesso profissional através de `wordpress.fabiodev.com`.

## 🏗️ Arquitetura Atual

```text
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16 + 100.64.0.0/16)                         │
│                                                                                     │
│ ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────────────┐ │
│ │   Subnet Pública    │  │   Subnet Pública    │  │      Subnet Privada         │ │
│ │   10.0.48.0/24      │  │   10.0.49.0/24      │  │     10.0.0.0/20             │ │
│ │   (us-east-1a)      │  │   (us-east-1b)      │  │     (us-east-1a)            │ │
│ │                     │  │                     │  │                             │ │
│ │ ┌─────────────────┐ │  │ ┌─────────────────┐ │  │ ┌─────────────────────────┐ │ │
│ │ │  NAT Gateway    │ │  │ │  NAT Gateway    │ │  │ │   Auto Scaling Group    │ │ │
│ │ │  (EIP Público)  │ │  │ │  (EIP Público)  │ │  │ │   (2-3 Instâncias)      │ │ │
│ │ └─────────────────┘ │  │ └─────────────────┘ │  │ │   WordPress + EFS       │ │ │
│ └─────────────────────┘  └─────────────────────┘  │ │   (Session Manager)     │ │ │
│           │                        │              │ └─────────────────────────┘ │ │
│ ┌─────────────────────────────────────────────────────────────┐ │                   │
│ │              Application Load Balancer                     │ │                   │
│ │                    (Internet-facing)                       │ │                   │
│ │          wordpress.fabiodev.com (Route 53 DNS)             │ │                   │
│ │              Health Check: 200,302 (WordPress)             │ │                   │
│ └─────────────────────────────────────────────────────────────┘ │                   │
│           │                        │                           │                   │
│ ┌─────────────────────┐                                       │                   │
│ │  Internet Gateway   │←──────────────────────────────────────┘                   │
│ └─────────────────────┘                                                           │
│                                                                                     │
│ ┌─────────────────────────────────────────────────────────────────────────────┐   │
│ │                     EFS - Elastic File System                              │   │
│ │                   Compartilhamento de Arquivos                             │   │
│ │                                                                             │   │
│ │ ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │   │
│ │ │   Mount Target  │  │  Access Point   │  │      Backup Automático      │ │   │
│ │ │   (Multi-AZ)    │  │   WordPress     │  │      (35 dias)              │ │   │
│ │ └─────────────────┘  └─────────────────┘  └─────────────────────────────┘ │   │
│ └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│ ┌─────────────────────────────────────────────────────────────────────────────┐   │
│ │                        Subnet Database (Isolada)                           │   │
│ │                   10.0.51.0/24 + 10.0.52.0/24                             │   │
│ │                   (us-east-1a + us-east-1b)                               │   │
│ │                                                                             │   │
│ │ ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │   │
│ │ │   RDS MySQL     │  │   Network ACL   │  │      Multi-AZ Standby       │ │   │
│ │ │   (t3.micro)    │  │   Restritiva    │  │      (us-east-1b)           │ │   │
│ │ └─────────────────┘  └─────────────────┘  └─────────────────────────────┘ │   │
│ │                                                                             │   │
│ │ ┌─────────────────────────────────────────────────────────────────────┐   │   │
│ │ │                        Route 53 DNS                                │   │   │
│ │ │   Hosted Zone: fabiodev.com                                         │   │   │
│ │ │   A Record: wordpress.fabiodev.com → ALB                            │   │   │
│ │ │   CNAME: www.wordpress.fabiodev.com                                 │   │   │
│ │ │   Health Checks: Monitoramento ativo                               │   │   │
│ │ └─────────────────────────────────────────────────────────────────────┘   │   │
│ └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│ ┌─────────────────────────────────────────────────────────────────────────────┐   │
│ │                      CloudWatch Alarms & Scaling                           │   │
│ │                                                                             │   │
│ │ ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │   │
│ │ │   CPU High      │  │   CPU Low       │  │    Scaling Policies         │ │   │
│ │ │   (>70%)        │  │   (<30%)        │  │    (+1/-1 instância)        │ │   │
│ │ └─────────────────┘  └─────────────────┘  └─────────────────────────────┘ │   │
│ └─────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 📋 Recursos Implementados

### ✅ Infraestrutura de Rede (Concluída)

- **VPC**: Rede virtual com CIDRs `10.0.0.0/16` + `100.64.0.0/16`
- **Subnets Públicas**: `10.0.48.0/24` (us-east-1a) + `10.0.49.0/24` (us-east-1b) - Para ALB e NAT Gateways
- **Subnet Privada**: `10.0.0.0/20` (us-east-1a) - Para instâncias WordPress
- **Subnets Database**: `10.0.51.0/24` (us-east-1a) + `10.0.52.0/24` (us-east-1b) - Para RDS MySQL Multi-AZ
- **Internet Gateway**: Acesso à internet para subnets públicas
- **NAT Gateways**: 2 NAT Gateways para alta disponibilidade (us-east-1a + us-east-1b)
- **Route Tables**: Roteamento configurado para cada tipo de subnet
- **Elastic IPs**: 2 IPs públicos fixos para os NAT Gateways
- **Network ACL**: Controle restritivo para subnets de banco de dados

### ✅ Application Load Balancer (Concluída) - Issue #6

- **ALB**: Internet-facing distribuído em 2 subnets públicas (us-east-1a + us-east-1b)
- **Target Group**: HTTP port 80 com health checks configurados
- **Listeners**: HTTP (porta 80) com forward para WordPress
- **Security Group ALB**: HTTP/HTTPS da internet, egress para VPC
- **High Availability**: ALB distribuído em múltiplas AZs
- **DNS Público**: `cloudpro-vpc-alb-*.us-east-1.elb.amazonaws.com`
- **Health Checks**: Path `/`, intervalo 30s, timeout 5s

### ✅ Route 53 DNS Personalizado (Concluída) - Issue #15

- **Hosted Zone**: `fabiodev.com` com configuração completa
- **Registro A (Alias)**: `wordpress.fabiodev.com` → ALB
- **Registro CNAME**: `www.wordpress.fabiodev.com` → `wordpress.fabiodev.com`
- **Health Checks**: Monitoramento HTTP ativo para ambos os domínios
- **DNS Profissional**: Acesso via domínio personalizado
- **Propagação Global**: DNS funcionando em servidores públicos (Google, Cloudflare, OpenDNS)
- **Custo**: $0.50/mês (hosted zone) + $1/mês (health checks)

### ✅ EFS - Elastic File System (Concluída) - Issue #2

- **EFS File System**: Sistema de arquivos compartilhado para WordPress
- **Performance Mode**: General Purpose (baixa latência, até 7000 ops/sec)
- **Throughput Mode**: Provisioned (10 MiB/s garantido)
- **Encryption**: Habilitada em repouso com KMS
- **Mount Targets**: Distribuídos em múltiplas AZs para alta disponibilidade
- **Access Point**: Configurado para WordPress (uid/gid 33 - www-data)
- **Backup Policy**: Backup automático diário com retenção de 35 dias
- **Lifecycle Policy**: Transição para IA após 30 dias (otimização de custos)
- **Security Group**: Porta 2049 (NFS) restrita às subnets privadas

### ✅ Auto Scaling Group (Concluída) - Issue #7

- **Launch Template**: AMI Amazon Linux 2, t3.micro, configuração WordPress
- **ASG Configuration**: Min 1, Max 3, Desired 2 instâncias
- **Health Checks**: ELB + EC2 com grace period de 300s
- **Scaling Policies**: Scale up (CPU >70%), Scale down (CPU <30%)
- **CloudWatch Alarms**: Monitoramento CPU com períodos de 2 minutos
- **Target Group Integration**: Registro automático no ALB
- **Multi-AZ Distribution**: Instâncias distribuídas em múltiplas AZs
- **Termination Policy**: OldestInstance para rolling updates
- **Detailed Monitoring**: Métricas CloudWatch em 1 minuto

### ✅ RDS MySQL (Concluída)

- **Instância RDS**: MySQL 8.0.44 em t3.micro com Multi-AZ
- **DB Subnet Group**: Configuração para subnets de banco de dados
- **Security Group**: Acesso restrito apenas do WordPress
- **Enhanced Monitoring**: Monitoramento detalhado habilitado
- **Backup Automático**: Retenção de 7 dias com janela configurada
- **Criptografia**: Storage criptografado com KMS

### ✅ SSM Parameter Store (Concluída)

- **Credenciais DB**: Username e password criptografados
- **Endpoint RDS**: Configuração centralizada para escalabilidade
- **Integração EC2**: WordPress busca configurações via AWS CLI
- **Segurança**: Parâmetros SecureString para dados sensíveis

### 🔧 Recursos Planejados (Issues GitHub)

- ~~**IAM Role SSM**: Para acesso seguro via Session Manager~~ ✅ **Concluído (Issue #1)**
- ~~**EFS**: Sistema de arquivos compartilhado~~ ✅ **Concluído (Issue #2)**
- ~~**Security Groups**: Controle de tráfego~~ ✅ **Concluído (Issue #3)**
- ~~**RDS MySQL**: Banco de dados WordPress~~ ✅ **Concluído (Issue #4)**
- ~~**Launch Template**: Configuração das instâncias~~ ✅ **Concluído (Issue #7)**
- ~~**Application Load Balancer**: Distribuição de carga~~ ✅ **Concluído (Issue #6)**
- ~~**Auto Scaling Group**: Escalabilidade automática~~ ✅ **Concluído (Issue #7)**
- **HTTPS/SSL**: Certificado SSL para ALB ([Issue #13](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/13))
- ~~**Route 53 DNS**: Domínio personalizado~~ ✅ **Concluído (Issue #15)**

## 📁 Estrutura do Projeto

O projeto está organizado por responsabilidades em arquivos separados:

```text
terraform_wordpress/
├── vpc.tf                     # VPC principal com DNS habilitado
├── public_subnets.tf          # Subnets públicas e Internet Gateway
├── private_subnets.tf         # Subnet privada, NAT Gateways e Elastic IPs
├── database_subnets.tf        # Subnets de banco de dados isoladas com Network ACL
├── alb.tf                     # Application Load Balancer com Target Groups
├── asg.tf                     # Auto Scaling Group com Launch Template (Issue #7)
├── efs.tf                     # Elastic File System compartilhado (Issue #2)
├── ec2.tf                     # Security Groups WordPress (migrado para ASG)
├── iam.tf                     # IAM Roles para SSM e RDS monitoring
├── rds.tf                     # RDS MySQL com Security Group
├── ssm.tf                     # SSM Parameter Store para credenciais
├── route53.tf                 # Route 53 DNS personalizado (Issue #15)
├── user_data.tpl              # Template de instalação WordPress
├── variables.tf               # Variáveis globais do projeto
├── outputs.tf                 # Outputs de todos os recursos
├── Makefile                   # Targets de validação e automação
├── terraform.tfvars.example   # Exemplo de configuração
├── .gitignore                 # Exclusões do Git
├── README.md                  # Esta documentação
├── DESTROY_GUIDE.md           # Guia para destroy seguro do RDS
├── docs/                      # Documentação técnica
│   ├── github-actions-setup.md
│   ├── issue-6-alb-execution-plan.md
│   └── aws-architecture-diagram.md  # Diagrama completo da arquitetura
├── environment/              # Configurações por ambiente
│   └── prod/
│       ├── backend.tfvars    # Configuração do backend S3
│       └── terraform.tfvars  # Variáveis do ambiente prod
└── scripts/                  # Scripts de validação e utilitários
    ├── safe_destroy.sh       # Script de destroy seguro automatizado
    └── validation/
        ├── validate_public_subnets.sh   # Validação de subnets públicas
        ├── validate_private_subnets.sh  # Validação de subnets privadas
        ├── validate_database_subnets.sh # Validação de subnets de banco de dados
        ├── validate_ssm_access.sh       # Validação Session Manager
        ├── validate_alb_access.sh       # Validação Application Load Balancer
        ├── validate_route53_dns.sh      # Validação Route 53 DNS (Issue #15)
        ├── simple_rds_test.sh           # Teste conectividade RDS
        └── check_wordpress_logs.sh      # Verificação logs WordPress
```

## 🚀 Pré-requisitos

1. **Terraform** instalado (versão >= 1.0)
2. **AWS CLI** configurado com credenciais válidas
3. **Permissões AWS** adequadas para criar recursos de rede

## 📦 Como Usar

### 1. Clone e Configure

```bash
# Clone o repositório (se aplicável)
git clone <seu-repositorio>
cd terraform_wordpress

# Inicialize o Terraform
terraform init -backend-config=environment/prod/backend.tfvars
```

### 2. Personalize as Variáveis (Opcional)

Crie um arquivo `terraform.tfvars` para personalizar as configurações:

```hcl
# terraform.tfvars
aws_region    = "us-east-1"
environment   = "dev"
project_name  = "meu-projeto"
vpc_cidr      = "10.0.0.0/16"

# Personalize os CIDRs das subnets se necessário
public_subnet_cidr    = "10.0.1.0/24"
private_subnet_cidrs  = ["10.0.2.0/24", "10.0.3.0/24"]
```

### 3. Planeje e Aplique

```bash
# Visualize o que será criado
terraform plan -var-file=./environment/prod/terraform.tfvars

# Aplique as mudanças
terraform apply -var-file=./environment/prod/terraform.tfvars
```

### 4. Verifique os Outputs

Após a aplicação, você verá informações importantes como:

- IDs da VPC e subnets
- IP público do NAT Gateway
- IDs das route tables

## 🔧 Variáveis Disponíveis

| Variável | Descrição | Valor Padrão |
| -------- | --------- | ------------ |
| `aws_region` | Região AWS | `us-east-1` |
| `environment` | Ambiente (dev/staging/prod) | `prod` |
| `project_name` | Nome do projeto | `cloudpro-vpc` |
| `vpc_cidr` | CIDR principal da VPC | `10.0.0.0/16` |
| `vpc_secondary_cidr` | CIDR secundário da VPC | `100.64.0.0/16` |
| `public_subnet_cidr` | CIDR da subnet pública | `10.0.48.0/24` |
| `private_subnet_cidr` | CIDR da subnet privada | `10.0.0.0/20` |
| `database_subnets` | Lista de subnets de banco de dados | `[{cidr="10.0.51.0/24", name="cloudpro-database-1a", availability_zone="us-east-1a"}]` |
| `db_username` | Username do banco MySQL | `wpuser` |
| `db_password` | Senha do banco MySQL | `(obrigatório)` |
| `root_domain_name` | Domínio raiz para Route 53 | `fabiodev.com` |
| `wordpress_subdomain` | Subdomínio para WordPress | `wordpress` |
| `enable_health_checks` | Habilitar health checks Route 53 | `true` |
| `ttl_default` | TTL padrão para registros DNS | `300` |

## 📊 Outputs Importantes

### Rede

- `vpc_id`: ID da VPC criada
- `vpc_cidr_block`: CIDR principal da VPC
- `vpc_additional_cidr_blocks`: CIDRs secundários da VPC
- `public_subnet_ids`: IDs das subnets públicas
- `private_subnet_ids`: IDs das subnets privadas
- `database_subnet_ids`: IDs das subnets de banco de dados
- `internet_gateway_id`: ID do Internet Gateway

### NAT Gateway e Conectividade

- `nat_gateway_ids`: IDs dos NAT Gateways
- `nat_gateway_public_ips`: IPs públicos dos NAT Gateways
- `elastic_ip_addresses`: Endereços dos Elastic IPs
- `elastic_ip_ids`: IDs dos Elastic IPs

### Roteamento

- `public_route_table_id`: ID da route table pública
- `private_route_table_ids`: IDs das route tables privadas
- `public_route_table_association_ids`: IDs das associações públicas
- `private_route_table_association_ids`: IDs das associações privadas

### Auto Scaling Group e EFS

- `asg_arn`: ARN do Auto Scaling Group
- `asg_name`: Nome do Auto Scaling Group
- `launch_template_id`: ID do Launch Template
- `launch_template_version`: Versão do Launch Template
- `scaling_policies_arns`: ARNs das políticas de scaling
- `cloudwatch_alarms`: IDs dos alarms CloudWatch
- `efs_file_system_id`: ID do sistema de arquivos EFS
- `efs_dns_name`: DNS name do EFS para mount
- `efs_access_point_id`: ID do access point WordPress
- `efs_mount_command`: Comando para montar EFS
- `efs_security_group_id`: ID do security group EFS

### WordPress e RDS

- `wordpress_security_group_id`: ID do Security Group WordPress
- `rds_endpoint`: Endpoint de conexão do RDS MySQL
- `rds_port`: Porta de conexão do RDS (3306)
- `rds_database_name`: Nome do banco de dados WordPress
- `ssm_db_username_parameter`: Parâmetro SSM para username
- `ssm_db_password_parameter`: Parâmetro SSM para password

### Application Load Balancer

- `alb_dns_name`: DNS name público do ALB para acesso ao WordPress
- `alb_arn`: ARN do Application Load Balancer
- `alb_zone_id`: Zone ID do ALB para configuração Route 53
- `target_group_arn`: ARN do Target Group WordPress
- `alb_security_group_id`: ID do Security Group do ALB

### Route 53 DNS

- `hosted_zone_id`: ID da hosted zone fabiodev.com
- `hosted_zone_name_servers`: Name servers da hosted zone
- `wordpress_domain`: Domínio completo do WordPress (wordpress.fabiodev.com)
- `wordpress_url`: URL completa do WordPress
- `route53_health_check_ids`: IDs dos health checks Route 53

### IAM

- `wordpress_iam_role_arn`: ARN da IAM Role WordPress SSM
- `wordpress_instance_profile_arn`: ARN do Instance Profile WordPress

## ⚠️ Requisitos Obrigatórios da AWS

### 🏗️ Application Load Balancer (ALB)

**Requisito Crítico**: ALB exige **pelo menos 2 subnets públicas em Availability Zones diferentes**

```hcl
# ❌ INCORRETO - Apenas 1 subnet (falhará)
public_subnets = [
  {
    name              = "public-subnet-1a"
    cidr              = "10.0.48.0/24"
    availability_zone = "us-east-1a"
  }
]

# ✅ CORRETO - 2+ subnets em AZs diferentes
public_subnets = [
  {
    name              = "public-subnet-1a"
    cidr              = "10.0.48.0/24"
    availability_zone = "us-east-1a"
  },
  {
    name              = "public-subnet-1b"
    cidr              = "10.0.49.0/24"
    availability_zone = "us-east-1b"
  }
]
```

**Por que é obrigatório:**

- ✅ **Alta disponibilidade**: ALB distribui tráfego entre múltiplas AZs
- ✅ **Tolerância a falhas**: Se uma AZ falhar, ALB continua funcionando
- ✅ **Requisito AWS**: Mínimo 2 subnets em AZs diferentes
- ❌ **Erro garantido**: ALB falhará na criação com apenas 1 subnet

### 🗄️ RDS Multi-AZ

**Requisito para RDS Multi-AZ**: **Pelo menos 2 subnets de banco em AZs diferentes**

```hcl
# ✅ CORRETO - DB Subnet Group com múltiplas AZs
database_subnets = [
  {
    name              = "database-subnet-1a"
    cidr              = "10.0.51.0/24"
    availability_zone = "us-east-1a"
  },
  {
    name              = "database-subnet-1b"
    cidr              = "10.0.52.0/24"
    availability_zone = "us-east-1b"
  }
]
```

**Benefícios:**

- ✅ **Failover automático**: RDS replica para AZ secundária
- ✅ **Backup cross-AZ**: Backups distribuídos geograficamente
- ✅ **Manutenção sem downtime**: Atualizações na AZ secundária primeiro

### 📋 Checklist de Subnets

Antes de implementar recursos AWS, verifique:

- [ ] **ALB**: 2+ subnets públicas em AZs diferentes
- [ ] **RDS Multi-AZ**: 2+ subnets de banco em AZs diferentes  
- [ ] **Auto Scaling**: Subnets privadas em múltiplas AZs
- [ ] **EFS**: Mount targets em múltiplas AZs
- [ ] **ElastiCache**: Subnet group com múltiplas AZs

## 🛡️ Boas Práticas Implementadas

### Segurança

- ✅ Subnets privadas para recursos sensíveis
- ✅ NAT Gateway para acesso controlado à internet
- ✅ SSM Parameter Store para credenciais criptografadas
- ✅ Security Groups com princípio de menor privilégio
- ✅ Session Manager para acesso sem SSH direto
- ✅ RDS em subnet isolada com backup automático
- ✅ EBS e RDS storage criptografados
- ✅ Tags padronizadas para organização
- ✅ DNS habilitado na VPC

### Organização

- ✅ **Estrutura modular** por responsabilidades
- ✅ **Separação clara** entre VPC, subnets, gateways e routing
- ✅ **Reutilização** de módulos para diferentes ambientes
- ✅ **Variáveis centralizadas** no nível raiz e por módulo
- ✅ **Outputs documentados** em cada módulo
- ✅ **Versionamento do provider** fixo

### Escalabilidade

- ✅ Uso de data sources para AZs
- ✅ Recursos distribuídos em múltiplas AZs
- ✅ **Módulos reutilizáveis** para diferentes projetos
- ✅ **Estrutura preparada** para expansão com novos módulos

## 🌐 Acesso ao WordPress

Após a implementação completa, o WordPress estará acessível através de **domínio personalizado**:

### **🎯 URL Principal (Route 53)**

**URL Personalizada**: `http://wordpress.fabiodev.com`

```bash
# Obter domínio personalizado
terraform output wordpress_url

# Exemplo de saída:
# http://wordpress.fabiodev.com
```

### **🔄 URL Alternativa (ALB)**

**URL de Backup**: Consulte o output `alb_dns_name` após `terraform apply`

```bash
# Obter URL do ALB (backup)
terraform output alb_dns_name

# Exemplo de saída:
# cloudpro-vpc-alb-58443922.us-east-1.elb.amazonaws.com
```

### **🚀 Acesso Múltiplo**

- ✅ **Principal**: `http://wordpress.fabiodev.com`
- ✅ **WWW**: `http://www.wordpress.fabiodev.com`
- ✅ **ALB Direto**: `http://cloudpro-vpc-alb-*.us-east-1.elb.amazonaws.com`

**Primeiro Acesso**: O WordPress redirecionará para `/wp-admin/install.php` para configuração inicial.

## 🧹 Limpeza

Para remover todos os recursos criados, use o script de destroy seguro:

```bash
# Opção 1: Script automatizado (recomendado)
./scripts/safe_destroy.sh

# Opção 2: Terraform padrão (pode falhar com RDS)
terraform destroy -var-file=./environment/prod/terraform.tfvars
```

⚠️ **Importante**: O RDS tem proteções que podem causar falha no `terraform destroy`. Use o script `safe_destroy.sh` ou consulte o `DESTROY_GUIDE.md` para instruções detalhadas.

## � Validação e Testes

O projeto inclui scripts de validação para verificar a infraestrutura:

### Scripts Disponíveis

```bash
# Validação completa (recomendado)
make validate-all

# Validações individuais
make validate-ssm      # Session Manager (Issue #1)
make validate-rds      # RDS MySQL (Issue #4) 
make validate-alb      # Application Load Balancer (Issue #6)
make validate-route53  # Route 53 DNS (Issue #15)
make validate-wordpress # WordPress logs

# Validações por Issue
make validate-issue-1  # Issue #1 - IAM Role SSM
make validate-issue-4  # Issue #4 - RDS MySQL
make validate-issue-6  # Issue #6 - Application Load Balancer
make validate-issue-15 # Issue #15 - Route 53 DNS

# Scripts diretos (uso avançado)
./scripts/safe_destroy.sh
./scripts/validation/validate_public_subnets.sh
./scripts/validation/validate_private_subnets.sh
./scripts/validation/validate_database_subnets.sh
./scripts/validation/validate_ssm_access.sh
./scripts/validation/validate_alb_access.sh
./scripts/validation/validate_route53_dns.sh
./scripts/validation/simple_rds_test.sh
./scripts/validation/check_wordpress_logs.sh
```

### Funcionalidades dos Scripts

- ✅ **Infraestrutura**: Verificação de recursos AWS (VPC, subnets, gateways)
- ✅ **Conectividade**: Teste de conectividade real com instâncias EC2 temporárias
- ✅ **Roteamento**: Validação de roteamento e NAT Gateways
- ✅ **Segurança**: Validação de Network ACLs e isolamento de banco de dados
- ✅ **Session Manager**: Suporte ao SSM para acesso seguro
- ✅ **Load Balancer**: Teste completo do ALB com health checks
- ✅ **Route 53 DNS**: Validação completa de DNS personalizado
- ✅ **Database**: Conectividade e performance do RDS MySQL
- ✅ **WordPress**: Verificação de logs e status da aplicação
- ✅ **Automação**: Limpeza automática de recursos de teste

## 📝 Roadmap de Desenvolvimento

### ✅ Issues Implementadas

1. **[Issue #1](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/1)**: IAM Role SSM ✅
2. **[Issue #2](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/2)**: EFS para arquivos compartilhados ✅
3. **[Issue #3](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/3)**: Security Groups ✅
4. **[Issue #4](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/4)**: RDS MySQL ✅
5. **[Issue #6](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/6)**: Application Load Balancer ✅
6. **[Issue #7](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/7)**: Auto Scaling Group ✅
7. **[Issue #15](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/15)**: Route 53 DNS Personalizado ✅

### 🚀 Próximas Issues

1. **[Issue #13](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/13)**: HTTPS/SSL para ALB
2. **[Issue #20](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/20)**: Replicação Cross-Region para EFS

### 🔄 Fases Futuras

- **HTTPS/SSL** com certificados ACM
- **CloudWatch** para monitoramento avançado
- **S3** para backups e mídia
- **CloudFront** para CDN global
- **ElastiCache** para cache Redis/Memcached
- **WAF** para proteção contra ataques
- **Backup Cross-Region** para disaster recovery

## 🤝 Contribuição

Para contribuir com melhorias:

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.
