# Infraestrutura AWS com Terraform - WordPress

Este projeto implementa uma infraestrutura completa na AWS para hospedar WordPress de forma escalável e segura. A arquitetura utiliza subnets privadas para as instâncias WordPress, com acesso via Session Manager e conectividade à internet através de NAT Gateway.

## 🏗️ Arquitetura Atual

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16 + 100.64.0.0/16)                  │
│                                                                         │
│  ┌─────────────────────┐  ┌─────────────────────────────────┐           │
│  │   Subnet Pública    │  │        Subnet Privada           │           │
│  │   10.0.48.0/24      │  │       10.0.0.0/20               │           │
│  │   (us-east-1a)      │  │       (us-east-1a)              │           │
│  │                     │  │                                 │           │
│  │  ┌─────────────────┐│  │  ┌─────────────────────────────┐│           │
│  │  │  NAT Gateway    ││  │  │    Instâncias WordPress     ││           │
│  │  │  (EIP Público)  ││  │  │    (Session Manager)        ││           │
│  │  └─────────────────┘│  │  └─────────────────────────────┘│           │
│  └─────────────────────┘  └─────────────────────────────────┘           │
│           │                              │                             │
│  ┌─────────────────────┐                 │                             │
│  │  Internet Gateway   │←────────────────┘                             │
│  └─────────────────────┘                                               │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              Subnet Database (Isolada)                         │   │
│  │                   10.0.51.0/24                                 │   │
│  │                   (us-east-1a)                                 │   │
│  │                                                                 │   │
│  │  ┌─────────────────┐  ┌─────────────────┐                     │   │
│  │  │   RDS MySQL     │  │   Network ACL   │                     │   │
│  │  │   (Futuro)      │  │   Restritiva    │                     │   │
│  │  └─────────────────┘  └─────────────────┘                     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## 📋 Recursos Implementados

### ✅ Infraestrutura de Rede (Concluída)

- **VPC**: Rede virtual com CIDRs `10.0.0.0/16` + `100.64.0.0/16`
- **Subnet Pública**: `10.0.48.0/24` (us-east-1a) - Para ALB e NAT Gateway
- **Subnet Privada**: `10.0.0.0/20` (us-east-1a) - Para instâncias WordPress
- **Subnet Database**: `10.0.51.0/24` (us-east-1a) - Para RDS MySQL (isolada)
- **Internet Gateway**: Acesso à internet para subnet pública
- **NAT Gateway**: Conectividade de saída para subnet privada
- **Route Tables**: Roteamento configurado para cada tipo de subnet
- **Elastic IP**: IP público fixo para o NAT Gateway
- **Network ACL**: Controle restritivo para subnet de banco de dados

### 🔧 Recursos Planejados (Issues GitHub)

- **IAM Role SSM**: Para acesso seguro via Session Manager ([Issue #1](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/1))
- **EFS**: Sistema de arquivos compartilhado ([Issue #2](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/2))
- **Security Groups**: Controle de tráfego ([Issue #3](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/3))
- **RDS MySQL**: Banco de dados WordPress ([Issue #4](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/4))
- **Launch Template**: Configuração das instâncias ([Issue #5](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/5))
- **Application Load Balancer**: Distribuição de carga ([Issue #6](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/6))
- **Auto Scaling Group**: Escalabilidade automática ([Issue #7](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/7))

## 📁 Estrutura do Projeto

O projeto está organizado por responsabilidades em arquivos separados:

```text
terraform_wordpress/
├── vpc.tf                     # VPC principal com DNS habilitado
├── public_subnets.tf          # Subnet pública e Internet Gateway
├── private_subnets.tf         # Subnet privada, NAT Gateway e Elastic IP
├── database_subnets.tf        # Subnet de banco de dados isolada com Network ACL
├── internet_gateway.tf        # Internet Gateway (referenciado)
├── variables.tf               # Variáveis globais do projeto
├── outputs.tf                 # Outputs de todos os recursos
├── terraform.tfvars.example   # Exemplo de configuração
├── .gitignore                 # Exclusões do Git
├── README.md                  # Esta documentação
├── GITHUB_ISSUES.md          # Issues planejadas para implementação
├── environment/              # Configurações por ambiente
│   └── prod/
│       ├── backend.tfvars    # Configuração do backend S3
│       └── terraform.tfvars  # Variáveis do ambiente prod
└── scripts/                  # Scripts de validação e utilitários
    └── validation/
        ├── validate_public_subnets.sh   # Validação de subnets públicas
        ├── validate_private_subnets.sh  # Validação de subnets privadas
        └── validate_database_subnets.sh # Validação de subnets de banco de dados
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
| `availability_zone` | Zona de disponibilidade | `us-east-1a` |

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

## 🛡️ Boas Práticas Implementadas

### Segurança

- ✅ Subnets privadas para recursos sensíveis
- ✅ NAT Gateway para acesso controlado à internet
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

## 🧹 Limpeza

Para remover todos os recursos criados:

```bash
terraform destroy
```

## � Validação e Testes

O projeto inclui scripts de validação para verificar a infraestrutura:

### Scripts Disponíveis

```bash
# Validar subnets públicas
./scripts/validation/validate_public_subnets.sh

# Validar subnets privadas  
./scripts/validation/validate_private_subnets.sh

# Validar subnets de banco de dados
./scripts/validation/validate_database_subnets.sh
```

### Funcionalidades dos Scripts

- ✅ Verificação de recursos AWS (VPC, subnets, gateways)
- ✅ Teste de conectividade real com instâncias EC2 temporárias
- ✅ Validação de roteamento e NAT Gateway
- ✅ Validação de Network ACLs e isolamento de banco de dados
- ✅ Suporte ao Session Manager para acesso seguro
- ✅ Limpeza automática de recursos de teste

## 📝 Roadmap de Desenvolvimento

### 🚀 Próxima Fase (Issues GitHub)

1. **[Issue #1](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/1)**: IAM Role SSM
2. **[Issue #2](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/2)**: EFS para arquivos compartilhados
3. **[Issue #3](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/3)**: Security Groups
4. **[Issue #4](https://github.com/fabiomartinsbrrj/terraform_wordpress/issues/4)**: RDS MySQL

### 🔄 Fases Futuras

- **Launch Template** com WordPress pré-configurado
- **Application Load Balancer** para alta disponibilidade
- **Auto Scaling Group** para escalabilidade automática
- **CloudWatch** para monitoramento
- **S3** para backups e mídia
- **CloudFront** para CDN

## 🤝 Contribuição

Para contribuir com melhorias:

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.
