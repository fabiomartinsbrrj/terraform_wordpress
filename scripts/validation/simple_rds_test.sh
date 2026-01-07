#!/bin/bash

# Script simplificado para testar conectividade RDS
set -e

echo "🔍 Teste simplificado de conectividade RDS..."

# Obter ID da instância WordPress
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=*wordpress*" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)

echo "✅ Instância: $INSTANCE_ID"

# Obter endpoint do RDS
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

echo "✅ RDS Endpoint: $RDS_ENDPOINT"

# Teste 1: Conectividade de rede
echo "🔍 Testando conectividade de rede..."
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"timeout 5 bash -c '</dev/tcp/$RDS_ENDPOINT/3306' && echo 'Porta 3306 OK' || echo 'Porta 3306 FALHOU'\"]" \
    --query 'Command.CommandId' \
    --output text)

sleep 3
OUTPUT=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query 'StandardOutputContent' \
    --output text)
echo "$OUTPUT"

# Teste 2: Verificar wp-config.php
echo "🔍 Verificando wp-config.php..."
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"grep -E 'DB_HOST|DB_NAME|DB_USER|DB_PASSWORD' /var/www/html/wp-config.php | head -4\"]" \
    --query 'Command.CommandId' \
    --output text)

sleep 3
OUTPUT=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query 'StandardOutputContent' \
    --output text)
echo "$OUTPUT"

# Teste 3: Teste PHP simples
echo "🔍 Testando conexão via PHP..."
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"php -r 'try { \$pdo = new PDO(\\\"mysql:host=$RDS_ENDPOINT;dbname=wordpress\\\", \\\"wpuser\\\", \\\"wpuser123456\\\"); echo \\\"✅ CONEXÃO RDS OK!\\\"; } catch(Exception \$e) { echo \\\"❌ ERRO: \\\" . \$e->getMessage(); }'\"]" \
    --query 'Command.CommandId' \
    --output text)

sleep 3
OUTPUT=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query 'StandardOutputContent' \
    --output text)
echo "$OUTPUT"

echo "🎉 Teste concluído!"
