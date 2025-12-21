# Infraestrutura AWS com Terraform - WordPress

Este projeto cria uma infraestrutura básica na AWS usando Terraform, seguindo as melhores práticas de desenvolvimento. A infraestrutura inclui uma VPC com 1 subnet pública e 2 subnets privadas.

## 🏗️ Arquitetura

```text
┌─────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                   │
│                                                         │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │  Subnet Pública │  │  Subnet Privada │              │
│  │   10.0.1.0/24   │  │   10.0.2.0/24   │              │
│  │                 │  │                 │              │
│  │  ┌─────────────┐│  │                 │              │
│  │  │NAT Gateway  ││  │                 │              │
│  │  └─────────────┘│  │                 │              │
│  └─────────────────┘  └─────────────────┘              │
│           │                     │                      │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │Internet Gateway │  │  Subnet Privada │              │
│  └─────────────────┘  │   10.0.3.0/24   │              │
│                       │                 │              │
│                       └─────────────────┘              │
└─────────────────────────────────────────────────────────┘
```

## 📋 Recursos Criados

- **VPC**: Rede virtual privada com CIDR `10.0.0.0/16`
- **Subnet Pública**: Para recursos que precisam de acesso direto à internet
- **2 Subnets Privadas**: Para recursos internos (bancos de dados, aplicações)
- **Internet Gateway**: Permite acesso à internet para a subnet pública
- **NAT Gateway**: Permite acesso à internet para as subnets privadas
- **Route Tables**: Configuração de roteamento para cada tipo de subnet
- **Elastic IP**: IP fixo para o NAT Gateway

## 📁 Estrutura Modular

O projeto segue uma arquitetura modular organizada por responsabilidades:

```text
terraform_wordpress/
├── main.tf                    # Configuração principal e chamadas dos módulos
├── variables.tf               # Variáveis globais do projeto
├── outputs.tf                 # Outputs principais da infraestrutura
├── terraform.tfvars.example   # Exemplo de configuração
├── .gitignore                 # Exclusões do Git
├── README.md                  # Documentação
└── modules/                   # Módulos organizados por responsabilidade
    ├── vpc/                   # Módulo da VPC
    │   ├── main.tf           # Recurso da VPC
    │   ├── variables.tf      # Variáveis do módulo VPC
    │   └── outputs.tf        # Outputs da VPC
    ├── subnets/              # Módulo das Subnets
    │   ├── main.tf           # Recursos das subnets
    │   ├── variables.tf      # Variáveis do módulo subnets
    │   └── outputs.tf        # Outputs das subnets
    ├── gateways/             # Módulo dos Gateways
    │   ├── main.tf           # Internet Gateway e NAT Gateway
    │   ├── variables.tf      # Variáveis do módulo gateways
    │   └── outputs.tf        # Outputs dos gateways
    └── routing/              # Módulo de Roteamento
        ├── main.tf           # Route tables e associações
        ├── variables.tf      # Variáveis do módulo routing
        └── outputs.tf        # Outputs das route tables
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
|----------|-----------|--------------|
| `aws_region` | Região AWS | `us-east-1` |
| `environment` | Ambiente (dev/staging/prod) | `dev` |
| `project_name` | Nome do projeto | `wordpress-infra` |
| `vpc_cidr` | CIDR da VPC | `10.0.0.0/16` |
| `public_subnet_cidr` | CIDR da subnet pública | `10.0.1.0/24` |
| `private_subnet_cidrs` | CIDRs das subnets privadas | `["10.0.2.0/24", "10.0.3.0/24"]` |

## 📊 Outputs Importantes

- `vpc_id`: ID da VPC criada
- `public_subnet_id`: ID da subnet pública
- `private_subnet_ids`: IDs das subnets privadas
- `nat_gateway_public_ip`: IP público do NAT Gateway

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

## 📝 Próximos Passos

Esta infraestrutura base pode ser expandida com:

1. **Security Groups** para controle de tráfego
2. **Application Load Balancer** para distribuição de carga
3. **RDS** para banco de dados
4. **EC2** instances para aplicações
5. **S3** buckets para armazenamento
6. **CloudFront** para CDN

## 🤝 Contribuição

Para contribuir com melhorias:

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.
