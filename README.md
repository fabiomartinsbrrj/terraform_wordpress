# Infraestrutura AWS com Terraform - WordPress

Este projeto implementa uma infraestrutura completa na AWS para hospedar WordPress de forma escalável e segura. A arquitetura utiliza subnets privadas para as instâncias WordPress, com acesso via Session Manager e conectividade à internet através de NAT Gateway.

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
│ │ │  NAT Gateway    │ │  │ │  NAT Gateway    │ │  │ │   Instâncias WordPress  │ │ │
│ │ │  (EIP Público)  │ │  │ │  (EIP Público)  │ │  │ │   (Session Manager)     │ │ │
│ │ └─────────────────┘ │  │ └─────────────────┘ │  │ └─────────────────────────┘ │ │
│ └─────────────────────┘  └─────────────────────┘  └─────────────────────────────┘ │
│           │                        │                           │                   │
│ ┌─────────────────────────────────────────────────────────────┐ │                   │
│ │              Application Load Balancer                     │ │                   │
│ │                    (Internet-facing)                       │ │                   │
│ │          cloudpro-vpc-alb-*.us-east-1.elb.amazonaws.com    │ │                   │
│ └─────────────────────────────────────────────────────────────┘ │                   │
│           │                        │                           │                   │
│ ┌─────────────────────┐                                       │                   │
│ │  Internet Gateway   │←──────────────────────────────────────┘                   │
│ └─────────────────────┘                                                           │
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

### ✅ WordPress EC2 (Concluída)

- **Instância EC2**: WordPress na subnet privada com Session Manager
- **Security Group**: Regras HTTP/HTTPS apenas do ALB, SSH/MySQL da VPC
- **IAM Role**: Acesso ao SSM Parameter Store e Session Manager
- **User Data**: Instalação automática do WordPress com WP-CLI
- **EBS**: Volume GP3 20GB criptografado
- **Acesso**: Apenas via ALB (não diretamente da internet)

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
- **EFS**: Sistema de arquivos compartilhado ([Issue #2](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/2))
- ~~**Security Groups**: Controle de tráfego~~ ✅ **Concluído (Issue #3)**
- ~~**RDS MySQL**: Banco de dados WordPress~~ ✅ **Concluído (Issue #4)**
- **Launch Template**: Configuração das instâncias ([Issue #5](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/5))
- ~~**Application Load Balancer**: Distribuição de carga~~ ✅ **Concluído (Issue #6)**
- **Auto Scaling Group**: Escalabilidade automática ([Issue #7](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/7))
- **HTTPS/SSL**: Certificado SSL para ALB ([Issue #13](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/13))

## 📁 Estrutura do Projeto

O projeto está organizado por responsabilidades em arquivos separados:

```text
terraform_wordpress/
├── vpc.tf                     # VPC principal com DNS habilitado
├── public_subnets.tf          # Subnets públicas e Internet Gateway
├── private_subnets.tf         # Subnet privada, NAT Gateways e Elastic IPs
├── database_subnets.tf        # Subnets de banco de dados isoladas com Network ACL
├── alb.tf                     # Application Load Balancer com Target Groups
├── ec2.tf                     # Instância WordPress com Security Group
├── iam.tf                     # IAM Roles para SSM e RDS monitoring
├── rds.tf                     # RDS MySQL com Security Group
├── ssm.tf                     # SSM Parameter Store para credenciais
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
│   └── issue-6-alb-execution-plan.md
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

### WordPress e RDS

- `wordpress_instance_id`: ID da instância EC2 WordPress
- `wordpress_instance_private_ip`: IP privado da instância WordPress
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

Após a implementação completa, o WordPress estará acessível através do ALB:

**URL de Acesso**: Consulte o output `alb_dns_name` após `terraform apply`

```bash
# Obter URL do WordPress
terraform output alb_dns_name

# Exemplo de saída:
# cloudpro-vpc-alb-58443922.us-east-1.elb.amazonaws.com
```

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
make validate-wordpress # WordPress logs

# Validações por Issue
make validate-issue-1  # Issue #1 - IAM Role SSM
make validate-issue-4  # Issue #4 - RDS MySQL
make validate-issue-6  # Issue #6 - Application Load Balancer

# Scripts diretos (uso avançado)
./scripts/safe_destroy.sh
./scripts/validation/validate_public_subnets.sh
./scripts/validation/validate_private_subnets.sh
./scripts/validation/validate_database_subnets.sh
./scripts/validation/validate_ssm_access.sh
./scripts/validation/validate_alb_access.sh
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
- ✅ **Database**: Conectividade e performance do RDS MySQL
- ✅ **WordPress**: Verificação de logs e status da aplicação
- ✅ **Automação**: Limpeza automática de recursos de teste

## 📝 Roadmap de Desenvolvimento

### ✅ Issues Implementadas

1. **[Issue #1](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/1)**: IAM Role SSM ✅
2. **[Issue #3](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/3)**: Security Groups ✅
3. **[Issue #4](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/4)**: RDS MySQL ✅
4. **[Issue #6](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/6)**: Application Load Balancer ✅

### 🚀 Próximas Issues

1. **[Issue #2](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/2)**: EFS para arquivos compartilhados
2. **[Issue #5](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/5)**: Launch Template
3. **[Issue #7](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/7)**: Auto Scaling Group
4. **[Issue #13](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/13)**: HTTPS/SSL para ALB

### 🔄 Fases Futuras

- **EFS** para arquivos compartilhados entre instâncias
- **Launch Template** com WordPress pré-configurado
- **Auto Scaling Group** para escalabilidade automática
- **HTTPS/SSL** com certificados ACM
- **CloudWatch** para monitoramento avançado
- **S3** para backups e mídia
- **CloudFront** para CDN global

## 🤝 Contribuição

Para contribuir com melhorias:

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.
