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
        --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
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
    
    SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=tag:Type,Values=Public" "Name=tag:Project,Values=${PROJECT_NAME}" \
        --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null)
    
    if [ -z "$SUBNETS" ]; then
        echo -e "${RED}❌ Nenhuma subnet pública encontrada${NC}\n"
        exit 1
    fi
    
    SUBNET_COUNT=$(echo "$SUBNETS" | wc -l)
    echo -e "${GREEN}✓ ${SUBNET_COUNT} subnet(s) pública(s) encontrada(s)${NC}"
    
    while IFS=$'\t' read -r subnet_id cidr az name; do
        echo -e "  • ${name}"
        echo -e "    ID: ${subnet_id}"
        echo -e "    CIDR: ${cidr}"
        echo -e "    AZ: ${az}"
    done <<< "$SUBNETS"
    echo ""
}

# Função para validar Internet Gateway
validate_internet_gateway() {
    echo -e "${YELLOW}[3/5] Validando Internet Gateway...${NC}"
    
    IGW_INFO=$(aws ec2 describe-internet-gateways \
        --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
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
    else
        echo -e "\n  ${RED}❌${NC} Nenhuma subnet associada à route table"
    fi
    echo ""
}

# Função para validar conectividade (resumo)
validate_connectivity() {
    echo -e "${YELLOW}[5/5] Resumo de Conectividade...${NC}"
    
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
validate_connectivity

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Validação concluída com sucesso!${NC}"
echo -e "${BLUE}========================================${NC}"
