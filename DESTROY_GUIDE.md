# 🔥 Guia de Destroy Seguro

## Problema Identificado

O `terraform destroy` pode falhar com RDS devido a dependências implícitas:

```bash
Error: Cannot delete the subnet group because at least one database instance is still using it
Error: deleting ENIs using Security Group: You do not have permission to access the specified resource
```

## ✅ Solução Recomendada

### Opção 1: Script Automatizado (Recomendado)

```bash
# Execute o script de destroy seguro
./scripts/safe_destroy.sh
```

### Opção 2: Terraform Normal (pode falhar)

```bash
# 1. Desabilitar proteção contra deleção
aws rds modify-db-instance \
  --db-instance-identifier cloudpro-vpc-mysql \
  --no-deletion-protection \
  --apply-immediately

# 2. Aguardar modificação
aws rds wait db-instance-available --db-instance-identifier cloudpro-vpc-mysql

# 3. Deletar instância RDS
aws rds delete-db-instance \
  --db-instance-identifier cloudpro-vpc-mysql \
  --skip-final-snapshot

# 4. Aguardar deleção completa
while aws rds describe-db-instances --db-instance-identifier cloudpro-vpc-mysql >/dev/null 2>&1; do
  echo "Aguardando RDS ser deletado..."
  sleep 10
done

# 5. Executar terraform destroy
terraform destroy --auto-approve -var-file=./environment/prod/terraform.tfvars
```

### ⚠️ Se a Opção 2 falhar

**Cenário 1 - Use o script completo:**

```bash
./scripts/safe_destroy.sh
```

**Cenário 2 - Execute apenas terraform destroy novamente:**

```bash
# Após executar os comandos manuais acima, execute:
terraform destroy --auto-approve -var-file=./environment/prod/terraform.tfvars
```

## 🔧 Correções Implementadas

1. **Deletion Protection**: Desabilitado por padrão em desenvolvimento
2. **Skip Final Snapshot**: Habilitado para acelerar destroy
3. **Lifecycle Rules**: Adicionados para ordem correta de criação/destruição
4. **Script Automatizado**: Para destroy seguro sem intervenção manual

## 📋 Dependências Resolvidas

- ✅ RDS Instance → DB Subnet Group
- ✅ RDS Instance → Security Group ENIs
- ✅ IAM Role → RDS Monitoring
- ✅ SSM Parameters → RDS Configuration
