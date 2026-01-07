#!/bin/bash

# Script para validar acesso via Session Manager
# Issue #1 - IAM Role SSM para instâncias WordPress

set -e

echo "🔍 Validando acesso via Session Manager..."

# Obter ID da instância WordPress
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=*wordpress*" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "❌ Nenhuma instância WordPress encontrada em execução"
    exit 1
fi

echo "✅ Instância encontrada: $INSTANCE_ID"

# Verificar se a instância está registrada no SSM
echo "🔍 Verificando registro no SSM..."
SSM_STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text 2>/dev/null || echo "None")

if [ "$SSM_STATUS" = "Online" ]; then
    echo "✅ Instância registrada no SSM e online"
else
    echo "❌ Instância não está registrada no SSM ou offline"
    echo "Status: $SSM_STATUS"
    exit 1
fi

# Testar comando simples via Session Manager
echo "🔍 Testando comando via Session Manager..."
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["echo \"SSM Test: $(date)\"","whoami","pwd"]' \
    --query 'Command.CommandId' \
    --output text)

echo "✅ Comando enviado: $COMMAND_ID"

# Aguardar execução
echo "⏳ Aguardando execução do comando..."
sleep 5

# Obter resultado
COMMAND_OUTPUT=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query 'StandardOutputContent' \
    --output text)

echo "📋 Resultado do comando:"
echo "$COMMAND_OUTPUT"

# Verificar IAM Role
echo "🔍 Verificando IAM Role da instância..."
INSTANCE_PROFILE=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
    --output text)

if [ "$INSTANCE_PROFILE" != "None" ] && [ -n "$INSTANCE_PROFILE" ]; then
    echo "✅ IAM Instance Profile configurado: $INSTANCE_PROFILE"
else
    echo "❌ IAM Instance Profile não encontrado"
    exit 1
fi

echo ""
echo "🎉 Validação do Session Manager concluída com sucesso!"
echo "✅ Issue #1 - IAM Role SSM está funcionando corretamente"
