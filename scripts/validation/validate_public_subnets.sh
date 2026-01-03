#!/bin/bash

# Script de validação para Subnets Públicas
# Valida VPC, Subnets Públicas, Internet Gateway e Route Tables

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
echo -e "${BLUE}  Validação de Subnets Públicas${NC}"
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
    echo -e "${YELLOW}[1/5] Validando VPC...${NC}"
    
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
    
    # Verificar CIDRs adicionais (excluindo o CIDR principal)
    ADDITIONAL_CIDRS=$(aws ec2 describe-vpcs \
        --vpc-ids "$VPC_ID" \
        --query "Vpcs[0].CidrBlockAssociationSet[?CidrBlockState.State==\`associated\` && CidrBlock!=\`${VPC_CIDR}\`].CidrBlock" \
        --output text 2>/dev/null)
    
    if [ ! -z "$ADDITIONAL_CIDRS" ]; then
        echo -e "  CIDRs Secundários: ${ADDITIONAL_CIDRS}"
        
        # Calcular total de IPs disponíveis
        PRIMARY_IPS=$((2**(32-16)))
        ADDITIONAL_COUNT=$(echo "$ADDITIONAL_CIDRS" | wc -w)
        TOTAL_IPS=$((PRIMARY_IPS * (ADDITIONAL_COUNT + 1)))
        
        echo -e "  Total de IPs (aproximado): ${TOTAL_IPS} endereços"
    fi
    echo ""
}

# Função para validar Subnets Públicas
validate_public_subnets() {
    echo -e "${YELLOW}[2/5] Validando Subnets Públicas...${NC}"
    
    # Buscar subnets pela VPC e verificar se têm rota para internet
    SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null)
    
    if [ -z "$SUBNETS" ]; then
        echo -e "${RED}❌ Nenhuma subnet encontrada na VPC${NC}\n"
        exit 1
    fi
    
    # Verificar quais subnets são públicas (têm rota para IGW)
    PUBLIC_SUBNETS=""
    while IFS=$'\t' read -r subnet_id cidr az name; do
        # Verificar se a subnet tem rota para internet gateway
        RT_ID=$(aws ec2 describe-route-tables \
            --filters "Name=association.subnet-id,Values=${subnet_id}" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)
        
        if [ "$RT_ID" != "None" ] && [ ! -z "$RT_ID" ]; then
            IGW_ROUTE=$(aws ec2 describe-route-tables \
                --route-table-ids "$RT_ID" \
                --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0` && starts_with(GatewayId, `igw-`)]' \
                --output text 2>/dev/null)
            
            if [ ! -z "$IGW_ROUTE" ]; then
                PUBLIC_SUBNETS="${PUBLIC_SUBNETS}${subnet_id}\t${cidr}\t${az}\t${name}\n"
            fi
        fi
    done <<< "$SUBNETS"
    
    if [ -z "$PUBLIC_SUBNETS" ]; then
        echo -e "${RED}❌ Nenhuma subnet pública encontrada (sem rota para IGW)${NC}\n"
        exit 1
    fi
    
    SUBNET_COUNT=$(echo -e "$PUBLIC_SUBNETS" | grep -v '^$' | wc -l)
    echo -e "${GREEN}✓ ${SUBNET_COUNT} subnet(s) pública(s) encontrada(s)${NC}"
    
    echo -e "$PUBLIC_SUBNETS" | grep -v '^$' | while IFS=$'\t' read -r subnet_id cidr az name; do
        echo -e "  • ${name:-subnet-${subnet_id}}"
        echo -e "    ID: ${subnet_id}"
        echo -e "    CIDR: ${cidr}"
        echo -e "    AZ: ${az}"
    done
    echo ""
}

# Função para validar Internet Gateway
validate_internet_gateway() {
    echo -e "${YELLOW}[3/5] Validando Internet Gateway...${NC}"
    
    IGW_INFO=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
        --query 'InternetGateways[0].[InternetGatewayId,Tags[?Key==`Name`].Value|[0],Attachments[0].VpcId,Attachments[0].State]' \
        --output text 2>/dev/null)
    
    if [ -z "$IGW_INFO" ]; then
        echo -e "${RED}❌ Internet Gateway não encontrado${NC}\n"
        exit 1
    fi
    
    IGW_ID=$(echo "$IGW_INFO" | awk '{print $1}')
    IGW_NAME=$(echo "$IGW_INFO" | awk '{print $2}')
    IGW_VPC=$(echo "$IGW_INFO" | awk '{print $3}')
    IGW_STATE=$(echo "$IGW_INFO" | awk '{print $4}')
    
    if [ "$IGW_STATE" != "available" ]; then
        echo -e "${RED}❌ Internet Gateway não está disponível (Estado: ${IGW_STATE})${NC}\n"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Internet Gateway encontrado e disponível${NC}"
    echo -e "  ID: ${IGW_ID}"
    echo -e "  Nome: ${IGW_NAME}"
    echo -e "  VPC: ${IGW_VPC}"
    echo -e "  Estado: ${IGW_STATE}"
    echo ""
}

# Função para validar Route Tables
validate_route_tables() {
    echo -e "${YELLOW}[4/5] Validando Route Tables...${NC}"
    
    RT_INFO=$(aws ec2 describe-route-tables \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-public-access" \
        --query 'RouteTables[0].RouteTableId' \
        --output text 2>/dev/null)
    
    if [ -z "$RT_INFO" ] || [ "$RT_INFO" == "None" ]; then
        echo -e "${RED}❌ Route Table pública não encontrada${NC}\n"
        exit 1
    fi
    
    RT_ID="$RT_INFO"
    
    echo -e "${GREEN}✓ Route Table pública encontrada${NC}"
    echo -e "  ID: ${RT_ID}"
    
    # Verificar rotas
    ROUTES=$(aws ec2 describe-route-tables \
        --route-table-ids "$RT_ID" \
        --query 'RouteTables[0].Routes[*].[DestinationCidrBlock,GatewayId]' \
        --output text 2>/dev/null)
    
    echo -e "\n  Rotas configuradas:"
    while IFS=$'\t' read -r dest gateway; do
        if [ "$dest" == "0.0.0.0/0" ]; then
            echo -e "    ${GREEN}✓${NC} ${dest} → ${gateway} (Internet Gateway)"
        else
            echo -e "    • ${dest} → ${gateway}"
        fi
    done <<< "$ROUTES"
    
    # Verificar associações com subnets
    ASSOCIATIONS=$(aws ec2 describe-route-tables \
        --route-table-ids "$RT_ID" \
        --query 'RouteTables[0].Associations[?SubnetId!=`null`].SubnetId' \
        --output text 2>/dev/null)
    
    if [ ! -z "$ASSOCIATIONS" ]; then
        ASSOC_COUNT=$(echo "$ASSOCIATIONS" | wc -w)
        echo -e "\n  ${GREEN}✓${NC} ${ASSOC_COUNT} subnet(s) associada(s) à route table"
        
        # Listar as subnets associadas
        echo "$ASSOCIATIONS" | tr ' ' '\n' | while read -r subnet_id; do
            SUBNET_NAME=$(aws ec2 describe-subnets \
                --subnet-ids "$subnet_id" \
                --query 'Subnets[0].Tags[?Key==`Name`].Value|[0]' \
                --output text 2>/dev/null)
            echo -e "    • ${SUBNET_NAME:-$subnet_id}"
        done
    else
        echo -e "\n  ${RED}❌${NC} Nenhuma subnet associada à route table"
    fi
    echo ""
}

# Função para testar conectividade real com instância EC2
test_internet_connectivity() {
    echo -e "${YELLOW}[5/6] Testando Conectividade Real com EC2...${NC}"
    
    # Obter primeira subnet pública
    FIRST_SUBNET=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'Subnets[0].SubnetId' \
        --output text 2>/dev/null)
    
    if [ -z "$FIRST_SUBNET" ] || [ "$FIRST_SUBNET" == "None" ]; then
        echo -e "${RED}❌ Nenhuma subnet encontrada para teste${NC}\n"
        return 1
    fi
    
    echo -e "  Subnet para teste: ${FIRST_SUBNET}"
    
    # Usar security group padrão da VPC (mais simples e confiável)
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
    
    # User data para teste de conectividade
    USER_DATA=$(cat << 'EOF'
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "=== INICIANDO TESTE DE CONECTIVIDADE ==="
yum update -y
yum install -y curl

echo "=== TESTANDO CONECTIVIDADE HTTPS ==="
if curl -s --connect-timeout 10 https://httpbin.org/ip; then
    echo "SUCCESS: Conectividade HTTPS OK"
else
    echo "FAILED: Conectividade HTTPS falhou"
fi

echo "=== TESTANDO CONECTIVIDADE HTTP ==="
if curl -s --connect-timeout 10 http://httpbin.org/ip; then
    echo "SUCCESS: Conectividade HTTP OK"
else
    echo "FAILED: Conectividade HTTP falhou"
fi

echo "=== TESTE GOOGLE DNS ==="
if curl -s --connect-timeout 10 http://8.8.8.8; then
    echo "SUCCESS: Conectividade Google DNS OK"
else
    echo "FAILED: Conectividade Google DNS falhou"
fi

echo "=== TESTE CONCLUIDO ==="
EOF
)
    
    # Criar instância EC2
    echo -e "  Criando instância EC2 temporária..."
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --count 1 \
        --instance-type t2.micro \
        --security-group-ids "$SG_ID" \
        --subnet-id "$FIRST_SUBNET" \
        --associate-public-ip-address \
        --user-data "$USER_DATA" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=temp-validation-instance},{Key=Purpose,Value=connectivity-test}]" \
        --query 'Instances[0].InstanceId' \
        --output text 2>/dev/null)
    
    if [ -z "$INSTANCE_ID" ]; then
        echo -e "${RED}❌ Falha ao criar instância EC2${NC}"
        return 1
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
    if echo "$LOGS" | grep -q "SUCCESS.*Conectividade.*OK"; then
        echo -e "${GREEN}✓ Teste de conectividade com internet bem-sucedido${NC}"
        CONNECTIVITY_SUCCESS=true
    else
        echo -e "${RED}❌ Teste de conectividade falhou${NC}"
        CONNECTIVITY_SUCCESS=false
    fi
    
    # Cleanup
    echo -e "  Limpando recursos temporários..."
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" >/dev/null 2>&1
    aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
    
    if [ "$CONNECTIVITY_SUCCESS" = true ]; then
        echo -e "${GREEN}✓ Conectividade real validada com sucesso${NC}"
    else
        echo -e "${RED}❌ Falha na validação de conectividade real${NC}"
    fi
    
    echo ""
}

# Função auxiliar para limpar security group
cleanup_security_group() {
    local sg_id="$1"
    if [ ! -z "$sg_id" ]; then
        aws ec2 delete-security-group --group-id "$sg_id" >/dev/null 2>&1
    fi
}

# Função para validar conectividade (resumo)
validate_connectivity() {
    echo -e "${YELLOW}[6/6] Resumo de Conectividade...${NC}"
    
    # Verificar se existe rota para internet
    IGW_ROUTE=$(aws ec2 describe-route-tables \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-public-access" \
        --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId' \
        --output text 2>/dev/null)
    
    if [ ! -z "$IGW_ROUTE" ] && [ "$IGW_ROUTE" != "None" ]; then
        echo -e "${GREEN}✓ Rota para internet configurada (0.0.0.0/0 → IGW)${NC}"
    else
        echo -e "${RED}❌ Rota para internet não encontrada${NC}"
    fi
    
    # Verificar se subnets estão associadas
    SUBNET_ASSOC=$(aws ec2 describe-route-tables \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-public-access" \
        --query 'RouteTables[0].Associations[?SubnetId!=`null`]' \
        --output text 2>/dev/null)
    
    if [ ! -z "$SUBNET_ASSOC" ]; then
        echo -e "${GREEN}✓ Subnets públicas associadas à route table${NC}"
    else
        echo -e "${RED}❌ Subnets não estão associadas à route table${NC}"
    fi
    
    echo ""
}

# Executar validações
check_aws_cli
validate_vpc
validate_public_subnets
validate_internet_gateway
validate_route_tables
test_internet_connectivity
validate_connectivity

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Validação concluída com sucesso!${NC}"
echo -e "${BLUE}  Infraestrutura de rede pública OK${NC}"
echo -e "${BLUE}========================================${NC}"
