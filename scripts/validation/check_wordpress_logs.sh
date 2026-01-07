#!/bin/bash

# Script para verificar logs da instância WordPress via Session Manager
# Monitora saúde e status dos serviços

set -e

echo "📋 Verificando logs da instância WordPress..."

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

# Função para executar comando via SSM
run_ssm_command() {
    local command="$1"
    local description="$2"
    
    echo "🔍 $description..."
    
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[\"$command\"]" \
        --query 'Command.CommandId' \
        --output text)
    
    sleep 3
    
    OUTPUT=$(aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query 'StandardOutputContent' \
        --output text)
    
    echo "$OUTPUT"
    echo "---"
}

# 1. Status geral do sistema
run_ssm_command "uptime && free -h && df -h /" "Verificando status geral do sistema"

# 2. Logs de inicialização (cloud-init)
run_ssm_command "tail -20 /var/log/cloud-init-output.log" "Verificando logs de inicialização (cloud-init)"

# 3. Logs do sistema
run_ssm_command "tail -20 /var/log/messages" "Verificando logs do sistema"

# 4. Status dos serviços web
run_ssm_command "systemctl status httpd nginx --no-pager -l" "Verificando status do Apache/Nginx"

# 5. Logs do Apache/Nginx
run_ssm_command "if [ -f /var/log/httpd/error_log ]; then tail -10 /var/log/httpd/error_log; elif [ -f /var/log/nginx/error.log ]; then tail -10 /var/log/nginx/error.log; else echo 'Logs de web server não encontrados'; fi" "Verificando logs de erro do web server"

# 6. Logs de acesso web
run_ssm_command "if [ -f /var/log/httpd/access_log ]; then tail -5 /var/log/httpd/access_log; elif [ -f /var/log/nginx/access.log ]; then tail -5 /var/log/nginx/access.log; else echo 'Logs de acesso não encontrados'; fi" "Verificando logs de acesso web"

# 7. Status do MySQL/MariaDB (se local)
run_ssm_command "systemctl status mysql mariadb --no-pager -l 2>/dev/null || echo 'MySQL/MariaDB não está rodando localmente (usando RDS)'" "Verificando status do banco local"

# 8. Processos em execução
run_ssm_command "ps aux | grep -E '(httpd|nginx|php|mysql)' | grep -v grep" "Verificando processos web em execução"

# 9. Conectividade de rede
run_ssm_command "curl -I http://localhost/ 2>/dev/null || echo 'Servidor web não está respondendo localmente'" "Testando conectividade local"

# 10. Espaço em disco
run_ssm_command "du -sh /var/www/* 2>/dev/null || echo 'Diretório web não encontrado'" "Verificando uso de espaço do WordPress"

echo "🎉 Verificação de logs concluída!"
echo "💡 Para logs em tempo real, use: aws ssm start-session --target $INSTANCE_ID"
