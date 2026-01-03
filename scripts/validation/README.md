# Scripts de Validação da Infraestrutura

Este diretório contém scripts para validar os recursos criados na AWS.

## Scripts Disponíveis

### `validate_public_subnets.sh`

Valida a criação e configuração das subnets públicas, incluindo:

- VPC e CIDRs (principal e adicionais)
- Subnets públicas
- Internet Gateway
- Route Tables e rotas
- Associações entre subnets e route tables

#### Uso

```bash
# Executar com valores padrão
./scripts/validation/validate_public_subnets.sh

# Ou especificar projeto e ambiente
PROJECT_NAME=cloudpro-vpc ENVIRONMENT=prod ./scripts/validation/validate_public_subnets.sh
```

#### Pré-requisitos

- AWS CLI instalado e configurado
- Credenciais AWS com permissões de leitura para EC2/VPC
- Recursos já criados via Terraform

#### Exemplo de Output

```
========================================
  Validação de Subnets Públicas
  Projeto: cloudpro-vpc
  Ambiente: prod
========================================

✓ AWS CLI encontrado

[1/5] Validando VPC...
✓ VPC encontrada
  ID: vpc-xxxxx
  Nome: cloudpro-vpc-vpc
  CIDR Principal: 10.0.0.0/16
  CIDRs Adicionais: 100.64.0.0/16

[2/5] Validando Subnets Públicas...
✓ 2 subnet(s) pública(s) encontrada(s)
  • cloudpro-vpc-public-1a
    ID: subnet-xxxxx
    CIDR: 10.0.1.0/24
    AZ: us-east-1a
  • cloudpro-vpc-public-1b
    ID: subnet-xxxxx
    CIDR: 10.0.2.0/24
    AZ: us-east-1b

[3/5] Validando Internet Gateway...
✓ Internet Gateway encontrado e disponível
  ID: igw-xxxxx
  Nome: cloudpro-vpc-igw
  VPC: vpc-xxxxx
  Estado: available

[4/5] Validando Route Tables...
✓ Route Table pública encontrada
  ID: rtb-xxxxx

  Rotas configuradas:
    ✓ 0.0.0.0/0 → igw-xxxxx (Internet Gateway)
    • 10.0.0.0/16 → local

  ✓ 2 subnet(s) associada(s) à route table

[5/5] Resumo de Conectividade...
✓ Rota para internet configurada (0.0.0.0/0 → IGW)
✓ Subnets públicas associadas à route table

========================================
✓ Validação concluída com sucesso!
========================================
```
