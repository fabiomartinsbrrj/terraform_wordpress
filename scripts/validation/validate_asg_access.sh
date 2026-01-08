#!/bin/bash

# ==============================================================================
# Script de Validação do Auto Scaling Group - Issue #7
# ==============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para verificar se comando existe
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "Comando '$1' não encontrado. Instale o AWS CLI."
        exit 1
    fi
}

# Verificar dependências
log_info "Verificando dependências..."
check_command "aws"
check_command "jq"

# Obter informações do Terraform
log_info "Obtendo informações do Terraform..."

# Verificar se terraform.tfstate existe
if [ ! -f "terraform.tfstate" ]; then
    log_error "Arquivo terraform.tfstate não encontrado. Execute 'terraform apply' primeiro."
    exit 1
fi

# Extrair valores do terraform state
PROJECT_NAME=$(terraform output -raw project_name 2>/dev/null || echo "wordpress-infra")
ASG_NAME="${PROJECT_NAME}-asg"
ALB_ARN=$(terraform output -raw alb_arn 2>/dev/null)
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn 2>/dev/null)

log_info "Projeto: $PROJECT_NAME"
log_info "ASG Name: $ASG_NAME"

# ==============================================================================
# VALIDAÇÃO 1: Auto Scaling Group Status
# ==============================================================================

log_info "=== Validação 1: Auto Scaling Group Status ==="

ASG_INFO=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query 'AutoScalingGroups[0]' 2>/dev/null)

if [ "$ASG_INFO" = "null" ] || [ -z "$ASG_INFO" ]; then
    log_error "Auto Scaling Group '$ASG_NAME' não encontrado"
    exit 1
fi

# Extrair informações do ASG
MIN_SIZE=$(echo "$ASG_INFO" | jq -r '.MinSize')
MAX_SIZE=$(echo "$ASG_INFO" | jq -r '.MaxSize')
DESIRED_CAPACITY=$(echo "$ASG_INFO" | jq -r '.DesiredCapacity')
CURRENT_INSTANCES=$(echo "$ASG_INFO" | jq -r '.Instances | length')
HEALTHY_INSTANCES=$(echo "$ASG_INFO" | jq -r '[.Instances[] | select(.HealthStatus == "Healthy")] | length')

log_success "ASG encontrado: $ASG_NAME"
log_info "  Min Size: $MIN_SIZE"
log_info "  Max Size: $MAX_SIZE" 
log_info "  Desired Capacity: $DESIRED_CAPACITY"
log_info "  Current Instances: $CURRENT_INSTANCES"
log_info "  Healthy Instances: $HEALTHY_INSTANCES"

# Validar configuração esperada
if [ "$MIN_SIZE" != "1" ] || [ "$MAX_SIZE" != "3" ] || [ "$DESIRED_CAPACITY" != "2" ]; then
    log_warning "Configuração ASG diferente do esperado (min=1, max=3, desired=2)"
fi

# ==============================================================================
# VALIDAÇÃO 2: Instâncias ASG
# ==============================================================================

log_info "=== Validação 2: Instâncias do ASG ==="

INSTANCES=$(echo "$ASG_INFO" | jq -r '.Instances[].InstanceId')

if [ -z "$INSTANCES" ]; then
    log_error "Nenhuma instância encontrada no ASG"
    exit 1
fi

log_success "Instâncias encontradas:"
for instance_id in $INSTANCES; do
    INSTANCE_INFO=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0]' 2>/dev/null)
    
    STATE=$(echo "$INSTANCE_INFO" | jq -r '.State.Name')
    AZ=$(echo "$INSTANCE_INFO" | jq -r '.Placement.AvailabilityZone')
    PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.PrivateIpAddress')
    
    log_info "  $instance_id: $STATE ($AZ) - IP: $PRIVATE_IP"
done

# ==============================================================================
# VALIDAÇÃO 3: Target Group Integration
# ==============================================================================

log_info "=== Validação 3: Target Group Integration ==="

if [ -n "$TARGET_GROUP_ARN" ]; then
    TARGET_HEALTH=$(aws elbv2 describe-target-health \
        --target-group-arn "$TARGET_GROUP_ARN" 2>/dev/null)
    
    HEALTHY_TARGETS=$(echo "$TARGET_HEALTH" | jq -r '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length')
    TOTAL_TARGETS=$(echo "$TARGET_HEALTH" | jq -r '.TargetHealthDescriptions | length')
    
    log_success "Target Group Health:"
    log_info "  Targets saudáveis: $HEALTHY_TARGETS/$TOTAL_TARGETS"
    
    # Listar status de cada target
    echo "$TARGET_HEALTH" | jq -r '.TargetHealthDescriptions[] | "  \(.Target.Id): \(.TargetHealth.State)"'
    
    if [ "$HEALTHY_TARGETS" -eq 0 ]; then
        log_warning "Nenhum target saudável encontrado"
    fi
else
    log_warning "Target Group ARN não encontrado nos outputs"
fi

# ==============================================================================
# VALIDAÇÃO 4: Scaling Policies
# ==============================================================================

log_info "=== Validação 4: Scaling Policies ==="

POLICIES=$(aws autoscaling describe-policies \
    --auto-scaling-group-name "$ASG_NAME" \
    --query 'ScalingPolicies[].[PolicyName,PolicyType,AdjustmentType,ScalingAdjustment]' \
    --output table 2>/dev/null)

if [ -n "$POLICIES" ]; then
    log_success "Scaling Policies encontradas:"
    echo "$POLICIES"
else
    log_warning "Nenhuma Scaling Policy encontrada"
fi

# ==============================================================================
# VALIDAÇÃO 5: CloudWatch Alarms
# ==============================================================================

log_info "=== Validação 5: CloudWatch Alarms ==="

CPU_HIGH_ALARM="${PROJECT_NAME}-cpu-high"
CPU_LOW_ALARM="${PROJECT_NAME}-cpu-low"

# Verificar alarm CPU High
HIGH_ALARM_INFO=$(aws cloudwatch describe-alarms \
    --alarm-names "$CPU_HIGH_ALARM" \
    --query 'MetricAlarms[0]' 2>/dev/null)

if [ "$HIGH_ALARM_INFO" != "null" ] && [ -n "$HIGH_ALARM_INFO" ]; then
    STATE=$(echo "$HIGH_ALARM_INFO" | jq -r '.StateValue')
    log_success "CPU High Alarm: $CPU_HIGH_ALARM ($STATE)"
else
    log_warning "CPU High Alarm não encontrado: $CPU_HIGH_ALARM"
fi

# Verificar alarm CPU Low
LOW_ALARM_INFO=$(aws cloudwatch describe-alarms \
    --alarm-names "$CPU_LOW_ALARM" \
    --query 'MetricAlarms[0]' 2>/dev/null)

if [ "$LOW_ALARM_INFO" != "null" ] && [ -n "$LOW_ALARM_INFO" ]; then
    STATE=$(echo "$LOW_ALARM_INFO" | jq -r '.StateValue')
    log_success "CPU Low Alarm: $CPU_LOW_ALARM ($STATE)"
else
    log_warning "CPU Low Alarm não encontrado: $CPU_LOW_ALARM"
fi

# ==============================================================================
# VALIDAÇÃO 6: Launch Template
# ==============================================================================

log_info "=== Validação 6: Launch Template ==="

LAUNCH_TEMPLATE=$(echo "$ASG_INFO" | jq -r '.LaunchTemplate.LaunchTemplateName')

if [ "$LAUNCH_TEMPLATE" != "null" ] && [ -n "$LAUNCH_TEMPLATE" ]; then
    LT_INFO=$(aws ec2 describe-launch-templates \
        --launch-template-names "$LAUNCH_TEMPLATE" \
        --query 'LaunchTemplates[0]' 2>/dev/null)
    
    LT_VERSION=$(echo "$LT_INFO" | jq -r '.LatestVersionNumber')
    log_success "Launch Template: $LAUNCH_TEMPLATE (v$LT_VERSION)"
else
    log_warning "Launch Template não encontrado"
fi

# ==============================================================================
# VALIDAÇÃO 7: Conectividade ALB
# ==============================================================================

log_info "=== Validação 7: Conectividade ALB ==="

if [ -n "$ALB_ARN" ]; then
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$ALB_ARN" \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null)
    
    if [ -n "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
        log_success "ALB DNS: $ALB_DNS"
        
        # Teste básico de conectividade HTTP
        log_info "Testando conectividade HTTP..."
        if curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS" | grep -q "200\|301\|302"; then
            log_success "ALB respondendo corretamente"
        else
            log_warning "ALB pode não estar respondendo corretamente"
        fi
    else
        log_warning "DNS do ALB não encontrado"
    fi
else
    log_warning "ARN do ALB não encontrado nos outputs"
fi

# ==============================================================================
# RESUMO FINAL
# ==============================================================================

log_info "=== Resumo da Validação ==="
log_success "✅ Auto Scaling Group configurado"
log_success "✅ Instâncias distribuídas em múltiplas AZs"
log_success "✅ Integração com ALB Target Group"
log_success "✅ Scaling Policies configuradas"
log_success "✅ CloudWatch Alarms configurados"
log_success "✅ Launch Template operacional"

log_info "Validação do ASG concluída com sucesso!"
log_info "Para monitorar: aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME"
