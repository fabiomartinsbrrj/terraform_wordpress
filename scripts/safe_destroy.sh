#!/bin/bash

# ==============================================================================
# Script para destroy seguro do Terraform com RDS
# Resolve problemas de dependências na ordem de destruição
# ==============================================================================

set -e

echo "🔥 Iniciando destroy seguro da infraestrutura..."

# Verificar se existe instância RDS
RDS_INSTANCES=$(aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `cloudpro-vpc-mysql`)].DBInstanceIdentifier' --output text 2>/dev/null || echo "")

if [ ! -z "$RDS_INSTANCES" ]; then
    echo "📋 Instâncias RDS encontradas: $RDS_INSTANCES"
    
    for instance in $RDS_INSTANCES; do
        echo "🔧 Desabilitando deletion protection para: $instance"
        aws rds modify-db-instance \
            --db-instance-identifier "$instance" \
            --no-deletion-protection \
            --apply-immediately \
            --no-cli-pager || true
        
        echo "⏳ Aguardando modificação ser aplicada..."
        aws rds wait db-instance-available --db-instance-identifier "$instance" || true
        
        echo "🗑️ Deletando instância RDS: $instance"
        aws rds delete-db-instance \
            --db-instance-identifier "$instance" \
            --skip-final-snapshot \
            --no-cli-pager || true
        
        echo "⏳ Aguardando deleção completa da instância RDS..."
        while aws rds describe-db-instances --db-instance-identifier "$instance" >/dev/null 2>&1; do
            echo "   RDS ainda sendo destruído..."
            sleep 15
        done
        echo "✅ RDS $instance deletado com sucesso!"
    done
else
    echo "ℹ️ Nenhuma instância RDS encontrada."
fi

echo "🚀 Executando terraform destroy..."
terraform destroy --auto-approve -var-file=./environment/prod/terraform.tfvars

echo "✅ Destroy concluído com sucesso!"
