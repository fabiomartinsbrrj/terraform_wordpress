#!/bin/bash

# ==============================================================================
# Script de Validação do Application Load Balancer - Issue #6
# ==============================================================================
# Descrição: Testa conectividade HTTP através do ALB e verifica health checks
# Autor: Terraform WordPress Project
# Versão: 1.0

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Função para obter outputs do Terraform
get_terraform_output() {
    local output_name=$1
    terraform output -raw "$output_name" 2>/dev/null || echo ""
}

# Função principal de validação
main() {
    echo "🔍 Validação do Application Load Balancer - Issue #6"
    echo "=================================================="
    echo ""

    # 1. Verificar se ALB existe
    log_info "1. Verificando se ALB existe..."
    ALB_DNS=$(get_terraform_output "alb_dns_name")
    ALB_ARN=$(get_terraform_output "alb_arn")
    
    if [[ -z "$ALB_DNS" ]]; then
        log_error "ALB DNS name não encontrado nos outputs do Terraform"
        exit 1
    fi
    
    log_success "ALB encontrado: $ALB_DNS"
    echo ""

    # 2. Verificar status do ALB
    log_info "2. Verificando status do ALB..."
    ALB_STATUS=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$ALB_ARN" \
        --query 'LoadBalancers[0].State.Code' \
        --output text 2>/dev/null || echo "unknown")
    
    if [[ "$ALB_STATUS" == "active" ]]; then
        log_success "ALB Status: $ALB_STATUS"
    else
        log_error "ALB Status: $ALB_STATUS (esperado: active)"
        exit 1
    fi
    echo ""

    # 3. Verificar target group health
    log_info "3. Verificando health do target group..."
    TARGET_GROUP_ARN=$(get_terraform_output "target_group_arn")
    
    if [[ -n "$TARGET_GROUP_ARN" ]]; then
        TARGET_HEALTH=$(aws elbv2 describe-target-health \
            --target-group-arn "$TARGET_GROUP_ARN" \
            --query 'TargetHealthDescriptions[0].TargetHealth.State' \
            --output text 2>/dev/null || echo "unknown")
        
        if [[ "$TARGET_HEALTH" == "healthy" ]]; then
            log_success "Target Health: $TARGET_HEALTH"
        elif [[ "$TARGET_HEALTH" == "initial" ]]; then
            log_warning "Target Health: $TARGET_HEALTH (ainda inicializando)"
        else
            log_error "Target Health: $TARGET_HEALTH (esperado: healthy)"
        fi
    else
        log_error "Target Group ARN não encontrado"
    fi
    echo ""

    # 4. Teste de conectividade HTTP
    log_info "4. Testando conectividade HTTP..."
    HTTP_URL="http://$ALB_DNS"
    
    # Teste com curl
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$HTTP_URL" || echo "000")
    
    if [[ "$HTTP_STATUS" == "200" ]]; then
        log_success "HTTP Status: $HTTP_STATUS (OK)"
    elif [[ "$HTTP_STATUS" == "302" ]]; then
        log_success "HTTP Status: $HTTP_STATUS (Redirect - WordPress setup)"
    elif [[ "$HTTP_STATUS" == "000" ]]; then
        log_error "HTTP Status: Timeout ou erro de conexão"
        exit 1
    else
        log_warning "HTTP Status: $HTTP_STATUS (inesperado)"
    fi
    echo ""

    # 5. Verificar headers de resposta
    log_info "5. Verificando headers de resposta..."
    HEADERS=$(curl -s -I --max-time 10 "$HTTP_URL" 2>/dev/null || echo "")
    
    if echo "$HEADERS" | grep -q "Server:"; then
        SERVER=$(echo "$HEADERS" | grep "Server:" | cut -d' ' -f2- | tr -d '\r')
        log_success "Server: $SERVER"
    fi
    
    if echo "$HEADERS" | grep -q "X-Powered-By:"; then
        PHP_VERSION=$(echo "$HEADERS" | grep "X-Powered-By:" | cut -d' ' -f2- | tr -d '\r')
        log_success "PHP: $PHP_VERSION"
    fi
    echo ""

    # 6. Teste de resolução DNS
    log_info "6. Testando resolução DNS do ALB..."
    
    # Tentar múltiplas ferramentas de DNS
    ALB_IPS=""
    
    # Método 1: dig (mais confiável)
    if command -v dig >/dev/null 2>&1; then
        ALB_IPS=$(dig +short "$ALB_DNS" 2>/dev/null | head -5)
    fi
    
    # Método 2: nslookup (fallback)
    if [[ -z "$ALB_IPS" ]] && command -v nslookup >/dev/null 2>&1; then
        ALB_IPS=$(nslookup "$ALB_DNS" 2>/dev/null | grep -A 10 "Name:" | grep "Address:" | awk '{print $2}' | head -5)
    fi
    
    # Método 3: getent (fallback Linux)
    if [[ -z "$ALB_IPS" ]] && command -v getent >/dev/null 2>&1; then
        ALB_IPS=$(getent hosts "$ALB_DNS" 2>/dev/null | awk '{print $1}' | head -5)
    fi
    
    # Método 4: ping (último recurso)
    if [[ -z "$ALB_IPS" ]]; then
        ALB_IPS=$(ping -c 1 "$ALB_DNS" 2>/dev/null | grep "PING" | sed -n 's/.*(\([^)]*\)).*/\1/p' || echo "")
    fi
    
    if [[ -n "$ALB_IPS" ]]; then
        log_success "DNS resolvido para IPs: $(echo $ALB_IPS | tr '\n' ' ')"
    else
        log_warning "DNS não resolvido (mas ALB está funcionando via HTTP)"
    fi
    echo ""

    # 7. Verificar listeners
    log_info "7. Verificando listeners do ALB..."
    LISTENERS=$(aws elbv2 describe-listeners \
        --load-balancer-arn "$ALB_ARN" \
        --query 'Listeners[].[Port,Protocol]' \
        --output text 2>/dev/null || echo "")
    
    if echo "$LISTENERS" | grep -q "80.*HTTP"; then
        log_success "Listener HTTP (80) configurado"
    else
        log_error "Listener HTTP (80) não encontrado"
    fi
    echo ""

    # 8. Resumo final
    echo "📊 Resumo da Validação"
    echo "====================="
    echo "🌐 ALB DNS: $ALB_DNS"
    echo "🎯 ALB Status: $ALB_STATUS"
    echo "❤️  Target Health: $TARGET_HEALTH"
    echo "🌍 HTTP Status: $HTTP_STATUS"
    echo ""

    # Verificação final
    if [[ "$ALB_STATUS" == "active" ]] && [[ "$HTTP_STATUS" =~ ^(200|302)$ ]]; then
        log_success "🎉 ALB está funcionando corretamente!"
        log_success "WordPress acessível em: $HTTP_URL"
        echo ""
        echo "🔗 Para acessar o WordPress:"
        echo "   curl -I $HTTP_URL"
        echo "   ou abra no navegador: $HTTP_URL"
        exit 0
    else
        log_error "❌ ALB não está funcionando corretamente"
        exit 1
    fi
}

# Executar função principal
main "$@"
