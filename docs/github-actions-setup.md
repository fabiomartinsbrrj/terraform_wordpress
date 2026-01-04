# Configuração do GitHub Actions para Terraform

Este documento descreve como configurar o GitHub Actions para validação automática de Terraform em Pull Requests.

## Workflow Criado

O arquivo `.github/workflows/terraform-pr.yml` foi criado com as seguintes funcionalidades:

- **Trigger**: Executado automaticamente em Pull Requests para branches `main` ou `master`
- **Filtros**: Apenas quando há mudanças em arquivos `.tf`, `.tfvars` ou no próprio workflow
- **Comandos executados**:
  - `terraform init`
  - `terraform fmt -check` (verificação de formatação)
  - `terraform validate` (validação de sintaxe)
  - `terraform plan -var-file=./environment/prod/terraform.tfvars` (plano usando variáveis de produção)

## Configuração Necessária

### 1. Secrets do GitHub

Configure os seguintes secrets no repositório GitHub:

1. Acesse: `Settings` → `Secrets and variables` → `Actions`
2. Adicione os secrets:

**Credenciais AWS:**

```bash
AWS_ACCESS_KEY_ID=sua_access_key_aqui
AWS_SECRET_ACCESS_KEY=sua_secret_key_aqui
```

**Variáveis Terraform (baseadas no seu terraform.tfvars de produção):**

```bash
TF_VAR_AWS_REGION=us-east-1
TF_VAR_ENVIRONMENT=prod
TF_VAR_PROJECT_NAME=wordpress-infra
TF_VAR_VPC_CIDR=10.0.0.0/16
TF_VAR_PUBLIC_SUBNETS=[{"name":"public-1","cidr":"10.0.1.0/24","availability_zone":"us-east-1a"},{"name":"public-2","cidr":"10.0.2.0/24","availability_zone":"us-east-1b"}]
TF_VAR_PRIVATE_SUBNETS=[{"name":"private-1","cidr":"10.0.3.0/24","availability_zone":"us-east-1a"},{"name":"private-2","cidr":"10.0.4.0/24","availability_zone":"us-east-1b"}]
TF_VAR_DATABASE_SUBNETS=[]
```

> **Nota:** Ajuste os valores das variáveis conforme seu arquivo `terraform.tfvars` de produção. Para variáveis complexas (listas/objetos), use formato JSON.

### 2. Permissões

O workflow já está configurado com as permissões necessárias:

- `contents: read` - Para ler o código
- `pull-requests: write` - Para comentar no PR

### 3. Solução para Variáveis Sensíveis

**Problema resolvido:** Como o arquivo `terraform.tfvars` não deve ser commitado (está no `.gitignore`), o workflow foi configurado para usar variáveis individuais via secrets do GitHub em vez de `-var-file`.

**Como funciona:**

- Cada variável Terraform é passada individualmente usando `-var="nome=${{ secrets.TF_VAR_NOME }}"`
- Isso mantém as boas práticas de segurança sem expor dados sensíveis no repositório
- As variáveis são configuradas como secrets no GitHub Actions

## Funcionalidades

### Comentário Automático no PR

O workflow adiciona automaticamente um comentário no PR com:

- Resultado do `terraform plan`
- Status da execução
- Informações sobre quem fez o push

### Verificações de Qualidade

- **Formatação**: Verifica se o código está formatado corretamente
- **Validação**: Confirma que a sintaxe Terraform está correta
- **Planejamento**: Mostra quais recursos serão criados/modificados

## Troubleshooting

### Erro de Credenciais AWS

- Verifique se os secrets `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` estão configurados
- Confirme se as credenciais têm permissões adequadas para os recursos Terraform

### Erro de Arquivo de Variáveis

- Certifique-se de que `./environment/prod/terraform.tfvars` existe
- Verifique se todas as variáveis necessárias estão definidas

### Erro de Formatação

- Execute `terraform fmt -recursive` localmente para corrigir a formatação
- Commit as mudanças antes de fazer o push

## Próximos Passos

1. Configure os secrets AWS no GitHub
2. Teste criando um PR com mudanças em arquivos Terraform
3. Verifique se o workflow executa corretamente
4. Ajuste as configurações conforme necessário
