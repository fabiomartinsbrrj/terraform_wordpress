#!/bin/bash

# Script de validação para Subnets Privadas
# Valida VPC, Subnets Privadas, NAT Gateway e conectividade via Session Manager

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
PROJECT_NAME="${PROJECT_NAME:-cloudpro-vpc}"
ENVIRONMENT="${ENVIRONMENT:-prod}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Validação de Subnets Privadas${NC}"
echo -e "${BLUE}  Projeto: ${PROJECT_NAME}${NC}"
echo -e "${BLUE}  Ambiente: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Função para verificar se AWS CLI está instalado
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI não está instalado${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ AWS CLI encontrado${NC}\n"
}

# Função para validar VPC
validate_vpc() {
    echo -e "${YELLOW}[1/6] Validando VPC...${NC}"
    
    VPC_INFO=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}" \
        --query 'Vpcs[0].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null)
    
    if [ -z "$VPC_INFO" ]; then
        echo -e "${RED}❌ VPC não encontrada${NC}\n"
        exit 1
    fi
    
    VPC_ID=$(echo "$VPC_INFO" | awk '{print $1}')
    VPC_CIDR=$(echo "$VPC_INFO" | awk '{print $2}')
    VPC_NAME=$(echo "$VPC_INFO" | awk '{print $3}')
    
    echo -e "${GREEN}✓ VPC encontrada${NC}"
    echo -e "  ID: ${VPC_ID}"
    echo -e "  Nome: ${VPC_NAME}"
    echo -e "  CIDR Principal: ${VPC_CIDR}"
    
    # Verificar CIDRs adicionais
    ADDITIONAL_CIDRS=$(aws ec2 describe-vpcs \
        --vpc-ids "$VPC_ID" \
        --query "Vpcs[0].CidrBlockAssociationSet[?CidrBlockState.State==\`associated\` && CidrBlock!=\`${VPC_CIDR}\`].CidrBlock" \
        --output text 2>/dev/null)
    
    if [ ! -z "$ADDITIONAL_CIDRS" ]; then
        echo -e "  CIDRs Secundários: ${ADDITIONAL_CIDRS}"
    fi
    echo ""
}

# Função para validar Subnets Privadas
validate_private_subnets() {
    echo -e "${YELLOW}[2/6] Validando Subnets Privadas...${NC}"
    
    # Buscar subnets pela VPC e verificar se NÃO têm rota para IGW
    SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null)
    
    if [ -z "$SUBNETS" ]; then
        echo -e "${RED}❌ Nenhuma subnet encontrada na VPC${NC}\n"
        exit 1
    fi
    
    # Buscar diretamente subnets que têm rota para NAT Gateway
    PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
        --output text | while IFS=$'\t' read -r subnet_id cidr az name; do
        
        if [ -z "$subnet_id" ]; then continue; fi
        
        # Verificar se a subnet tem rota para NAT gateway
        RT_ID=$(aws ec2 describe-route-tables \
            --filters "Name=association.subnet-id,Values=${subnet_id}" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)
        
        if [ "$RT_ID" != "None" ] && [ ! -z "$RT_ID" ]; then
            NAT_ROUTE=$(aws ec2 describe-route-tables \
                --route-table-ids "$RT_ID" \
                --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0` && starts_with(NatGatewayId, `nat-`)]' \
                --output text 2>/dev/null)
            
            if [ ! -z "$NAT_ROUTE" ]; then
                echo "${subnet_id}\t${cidr}\t${az}\t${name}"
            fi
        fi
    done)
    
    if [ -z "$PRIVATE_SUBNETS" ]; then
        echo -e "${RED}❌ Nenhuma subnet privada encontrada (sem rota para NAT Gateway)${NC}\n"
        exit 1
    fi
    
    SUBNET_COUNT=$(echo -e "$PRIVATE_SUBNETS" | grep -v '^$' | wc -l)
    echo -e "${GREEN}✓ ${SUBNET_COUNT} subnet(s) privada(s) encontrada(s)${NC}"
    
    echo -e "$PRIVATE_SUBNETS" | grep -v '^$' | while IFS=$'\t' read -r subnet_id cidr az name; do
        echo -e "  • ${name:-subnet-${subnet_id}}"
        echo -e "    ID: ${subnet_id}"
        echo -e "    CIDR: ${cidr}"
        echo -e "    AZ: ${az}"
    done
    echo ""
}

# Função para validar NAT Gateway
validate_nat_gateway() {
    echo -e "${YELLOW}[3/6] Validando NAT Gateway...${NC}"
    
    NAT_INFO=$(aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=${VPC_ID}" "Name=state,Values=available" \
        --query 'NatGateways[0].[NatGatewayId,Tags[?Key==`Name`].Value|[0],SubnetId,PublicIp,State]' \
        --output text 2>/dev/null)
    
    if [ -z "$NAT_INFO" ] || [ "$NAT_INFO" == "None" ]; then
        echo -e "${RED}❌ NAT Gateway não encontrado${NC}\n"
        exit 1
    fi
    
    NAT_ID=$(echo "$NAT_INFO" | awk '{print $1}')
    NAT_NAME=$(echo "$NAT_INFO" | awk '{print $2}')
    NAT_SUBNET=$(echo "$NAT_INFO" | awk '{print $3}')
    NAT_IP=$(echo "$NAT_INFO" | awk '{print $4}')
    NAT_STATE=$(echo "$NAT_INFO" | awk '{print $5}')
    
    echo -e "${GREEN}✓ NAT Gateway encontrado e disponível${NC}"
    echo -e "  ID: ${NAT_ID}"
    echo -e "  Nome: ${NAT_NAME}"
    echo -e "  Subnet: ${NAT_SUBNET}"
    echo -e "  IP Público: ${NAT_IP}"
    echo -e "  Estado: ${NAT_STATE}"
    echo ""
}

# Função para validar Route Tables Privadas
validate_private_route_tables() {
    echo -e "${YELLOW}[4/6] Validando Route Tables Privadas...${NC}"
    
    # Buscar route tables que têm rota para NAT Gateway
    RT_INFO=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'RouteTables[?Routes[?starts_with(NatGatewayId, `nat-`)]].[RouteTableId,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null)
    
    if [ -z "$RT_INFO" ]; then
        echo -e "${RED}❌ Nenhuma route table privada encontrada${NC}\n"
        exit 1
    fi
    
    RT_COUNT=$(echo "$RT_INFO" | wc -l)
    echo -e "${GREEN}✓ ${RT_COUNT} route table(s) privada(s) encontrada(s)${NC}"
    
    while IFS=$'\t' read -r rt_id rt_name; do
        echo -e "  • ${rt_name:-$rt_id}"
        echo -e "    ID: ${rt_id}"
        
        # Verificar rotas
        ROUTES=$(aws ec2 describe-route-tables \
            --route-table-ids "$rt_id" \
            --query 'RouteTables[0].Routes[*].[DestinationCidrBlock,NatGatewayId,GatewayId]' \
            --output text 2>/dev/null)
        
        echo -e "    Rotas configuradas:"
        while IFS=$'\t' read -r dest nat_gw igw; do
            if [ "$dest" == "0.0.0.0/0" ] && [ ! -z "$nat_gw" ]; then
                echo -e "      ${GREEN}✓${NC} ${dest} → ${nat_gw} (NAT Gateway)"
            elif [ "$igw" == "local" ]; then
                echo -e "      • ${dest} → local"
            fi
        done <<< "$ROUTES"
        
        # Verificar associações
        ASSOCIATIONS=$(aws ec2 describe-route-tables \
            --route-table-ids "$rt_id" \
            --query 'RouteTables[0].Associations[?SubnetId!=`null`].SubnetId' \
            --output text 2>/dev/null)
        
        if [ ! -z "$ASSOCIATIONS" ]; then
            ASSOC_COUNT=$(echo "$ASSOCIATIONS" | wc -w)
            echo -e "    ${GREEN}✓${NC} ${ASSOC_COUNT} subnet(s) associada(s)"
        fi
        echo ""
    done <<< "$RT_INFO"
}

# Função para testar conectividade via Session Manager
test_private_connectivity() {
    echo -e "${YELLOW}[5/6] Testando Conectividade via Session Manager...${NC}"
    
    # Verificar se Session Manager está disponível
    if ! aws ssm describe-instance-information --query 'InstanceInformationList[0]' --output text >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Session Manager não configurado ou sem instâncias${NC}"
        echo -e "  Para testar conectividade, você precisará:"
        echo -e "  1. Criar uma instância na subnet privada"
        echo -e "  2. Instalar o SSM Agent (já vem no Amazon Linux 2)"
        echo -e "  3. Configurar IAM role com AmazonSSMManagedInstanceCore"
        echo ""
        return 0
    fi
    
    # Obter primeira subnet privada
    FIRST_PRIVATE_SUBNET=$(echo -e "$PRIVATE_SUBNETS" | grep -v '^$' | head -1 | awk -F'\t' '{print $1}')
    
    if [ -z "$FIRST_PRIVATE_SUBNET" ]; then
        echo -e "${RED}❌ Nenhuma subnet privada encontrada para teste${NC}\n"
        return 1
    fi
    
    echo -e "  Subnet para teste: ${FIRST_PRIVATE_SUBNET}"
    
    # Usar security group padrão da VPC
    echo -e "  Obtendo security group padrão da VPC..."
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=default" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null)
    
    if [ -z "$SG_ID" ] || [ "$SG_ID" == "None" ]; then
        echo -e "${RED}❌ Falha ao obter security group padrão${NC}\n"
        return 1
    fi
    
    echo -e "  Usando security group padrão: ${SG_ID}"
    
    # Obter AMI mais recente do Amazon Linux 2
    AMI_ID=$(aws ec2 describe-images \
        --owners amazon \
        --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text 2>/dev/null)
    
    if [ -z "$AMI_ID" ]; then
        echo -e "${RED}❌ Falha ao obter AMI${NC}"
        return 1
    fi
    
    echo -e "  AMI selecionada: ${AMI_ID}"
    
    # User data para teste de conectividade via NAT Gateway
    USER_DATA=$(cat << 'EOF'
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "=== INICIANDO TESTE DE CONECTIVIDADE PRIVADA ==="
yum update -y
yum install -y curl

echo "=== TESTANDO CONECTIVIDADE HTTPS ==="
if curl -s --connect-timeout 10 https://httpbin.org/ip; then
    echo "SUCCESS: Conectividade HTTPS via NAT Gateway OK"
else
    echo "FAILED: Conectividade HTTPS via NAT Gateway falhou"
fi

echo "=== TESTANDO CONECTIVIDADE HTTP ==="
if curl -s --connect-timeout 10 http://httpbin.org/ip; then
    echo "SUCCESS: Conectividade HTTP via NAT Gateway OK"
else
    echo "FAILED: Conectividade HTTP via NAT Gateway falhou"
fi

echo "=== TESTE CONCLUIDO ==="
EOF
)
    
    # Criar instância EC2 na subnet privada
    echo -e "  Criando instância EC2 temporária na subnet privada..."
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --count 1 \
        --instance-type t2.micro \
        --security-group-ids "$SG_ID" \
        --subnet-id "$FIRST_PRIVATE_SUBNET" \
        --user-data "$USER_DATA" \
        --iam-instance-profile Name=SSMInstanceProfile \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=temp-private-validation},{Key=Purpose,Value=connectivity-test}]" \
        --query 'Instances[0].InstanceId' \
        --output text 2>/dev/null)
    
    if [ -z "$INSTANCE_ID" ]; then
        echo -e "${YELLOW}⚠️  Falha ao criar instância (pode ser falta de IAM role para SSM)${NC}"
        echo -e "  Para testar conectividade privada, você precisa:"
        echo -e "  1. Criar IAM role com política AmazonSSMManagedInstanceCore"
        echo -e "  2. Criar instance profile SSMInstanceProfile"
        echo -e "  3. Executar novamente o teste"
        echo ""
        return 0
    fi
    
    echo -e "  Instância criada: ${INSTANCE_ID}"
    echo -e "  Aguardando instância ficar pronta..."
    
    # Aguardar instância ficar running
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
    
    # Aguardar mais um pouco para o user data executar
    echo -e "  Aguardando execução dos testes (60s)..."
    sleep 60
    
    # Obter logs da instância
    echo -e "  Obtendo resultados do teste..."
    LOGS=$(aws ec2 get-console-output \
        --instance-id "$INSTANCE_ID" \
        --query 'Output' \
        --output text 2>/dev/null)
    
    # Verificar resultados
    if echo "$LOGS" | grep -q "SUCCESS.*Conectividade.*via NAT Gateway OK"; then
        echo -e "${GREEN}✓ Teste de conectividade via NAT Gateway bem-sucedido${NC}"
        CONNECTIVITY_SUCCESS=true
    else
        echo -e "${RED}❌ Teste de conectividade via NAT Gateway falhou${NC}"
        CONNECTIVITY_SUCCESS=false
    fi
    
    # Cleanup
    echo -e "  Limpando recursos temporários..."
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" >/dev/null 2>&1
    aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
    
    if [ "$CONNECTIVITY_SUCCESS" = true ]; then
        echo -e "${GREEN}✓ Conectividade privada validada com sucesso${NC}"
    else
        echo -e "${RED}❌ Falha na validação de conectividade privada${NC}"
    fi
    
    echo ""
}

# Função para resumo de conectividade
validate_connectivity_summary() {
    echo -e "${YELLOW}[6/6] Resumo de Conectividade Privada...${NC}"
    
    # Verificar se existe rota para NAT Gateway
    NAT_ROUTE=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'RouteTables[?Routes[?DestinationCidrBlock==`0.0.0.0/0` && starts_with(NatGatewayId, `nat-`)]]' \
        --output text 2>/dev/null)
    
    if [ ! -z "$NAT_ROUTE" ]; then
        echo -e "${GREEN}✓ Rota para internet via NAT Gateway configurada${NC}"
    else
        echo -e "${RED}❌ Rota para NAT Gateway não encontrada${NC}"
    fi
    
    # Verificar se subnets privadas estão associadas
    PRIVATE_ASSOC=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'RouteTables[?Routes[?starts_with(NatGatewayId, `nat-`)]].Associations[?SubnetId!=`null`]' \
        --output text 2>/dev/null)
    
    if [ ! -z "$PRIVATE_ASSOC" ]; then
        echo -e "${GREEN}✓ Subnets privadas associadas às route tables${NC}"
    else
        echo -e "${RED}❌ Subnets privadas não estão associadas${NC}"
    fi
    
    echo -e "\n${BLUE}Instruções para acesso às instâncias privadas:${NC}"
    echo -e "  ${GREEN}Session Manager:${NC} aws ssm start-session --target INSTANCE_ID"
    echo -e "  ${GREEN}Bastion Host:${NC} Criar instância na subnet pública como jump server"
    echo ""
}

# Executar validações
check_aws_cli
validate_vpc
validate_private_subnets
validate_nat_gateway
validate_private_route_tables
test_private_connectivity
validate_connectivity_summary

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Validação de subnets privadas concluída!${NC}"
echo -e "${BLUE}  Infraestrutura de rede privada OK${NC}"
echo -e "${BLUE}========================================${NC}"
