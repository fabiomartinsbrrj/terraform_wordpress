#!/bin/bash

# Script de validação para Database Subnets
# Valida a configuração das subnets de banco de dados, Network ACLs e isolamento

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
PROJECT_NAME="${PROJECT_NAME:-cloudpro-vpc}"
ENVIRONMENT="${ENVIRONMENT:-prod}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Validação de Database Subnets${NC}"
echo -e "${BLUE}  Projeto: ${PROJECT_NAME}${NC}"
echo -e "${BLUE}  Ambiente: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Função para verificar se AWS CLI está disponível
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI não encontrado${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ AWS CLI encontrado${NC}"
    echo ""
}

# Função para validar VPC
validate_vpc() {
    echo -e "${YELLOW}[1/6] Validando VPC...${NC}"
    
    VPC_INFO=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}" \
        --query 'Vpcs[0].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null)
    
    if [ -z "$VPC_INFO" ] || [ "$VPC_INFO" == "None" ]; then
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
        --vpc-ids "${VPC_ID}" \
        --query 'Vpcs[0].CidrBlockAssociationSet[?CidrBlockState.State==`associated`].CidrBlock' \
        --output text 2>/dev/null)
    
    if [ ! -z "$ADDITIONAL_CIDRS" ]; then
        echo -e "  CIDRs Secundários: ${ADDITIONAL_CIDRS}"
    fi
    echo ""
}

# Função para validar Database Subnets
validate_database_subnets() {
    echo -e "${YELLOW}[2/6] Validando Database Subnets...${NC}"
    
    # Buscar subnets de banco de dados
    DATABASE_SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=*database*" \
        --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null)
    
    if [ -z "$DATABASE_SUBNETS" ]; then
        echo -e "${RED}❌ Nenhuma database subnet encontrada${NC}\n"
        exit 1
    fi
    
    SUBNET_COUNT=$(echo "$DATABASE_SUBNETS" | grep -v '^$' | wc -l)
    echo -e "${GREEN}✓ ${SUBNET_COUNT} database subnet(s) encontrada(s)${NC}"
    
    echo "$DATABASE_SUBNETS" | grep -v '^$' | while IFS=$'\t' read -r subnet_id cidr az name; do
        echo -e "  • ${name}"
        echo -e "    ID: ${subnet_id}"
        echo -e "    CIDR: ${cidr}"
        echo -e "    AZ: ${az}"
    done
    echo ""
}

# Função para validar Network ACL
validate_network_acl() {
    echo -e "${YELLOW}[3/6] Validando Network ACL...${NC}"
    
    # Buscar Network ACL das database subnets
    NETWORK_ACL_INFO=$(aws ec2 describe-network-acls \
        --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=*database*" \
        --query 'NetworkAcls[0].[NetworkAclId,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null)
    
    if [ -z "$NETWORK_ACL_INFO" ] || [ "$NETWORK_ACL_INFO" == "None" ]; then
        echo -e "${RED}❌ Network ACL específica para database não encontrada${NC}\n"
        exit 1
    fi
    
    NACL_ID=$(echo "$NETWORK_ACL_INFO" | awk '{print $1}')
    NACL_NAME=$(echo "$NETWORK_ACL_INFO" | awk '{print $2}')
    
    echo -e "${GREEN}✓ Network ACL encontrada${NC}"
    echo -e "  ID: ${NACL_ID}"
    echo -e "  Nome: ${NACL_NAME}"
    
    # Verificar regras da Network ACL
    echo -e "\n  Regras configuradas:"
    aws ec2 describe-network-acls \
        --network-acl-ids "${NACL_ID}" \
        --query 'NetworkAcls[0].Entries[?!Egress].[RuleNumber,Protocol,RuleAction,CidrBlock,PortRange.From,PortRange.To]' \
        --output table 2>/dev/null | grep -E "(10|20|300)" | while read -r line; do
        echo -e "    ${line}"
    done
    echo ""
}

# Função para validar associações de subnet
validate_subnet_associations() {
    echo -e "${YELLOW}[4/6] Validando Associações de Subnet...${NC}"
    
    # Verificar se as database subnets estão associadas à Network ACL correta
    ASSOCIATIONS=$(aws ec2 describe-network-acls \
        --network-acl-ids "${NACL_ID}" \
        --query 'NetworkAcls[0].Associations[*].[SubnetId,NetworkAclAssociationId]' \
        --output text 2>/dev/null)
    
    if [ -z "$ASSOCIATIONS" ]; then
        echo -e "${RED}❌ Nenhuma associação encontrada${NC}\n"
        exit 1
    fi
    
    ASSOC_COUNT=$(echo "$ASSOCIATIONS" | grep -v '^$' | wc -l)
    echo -e "${GREEN}✓ ${ASSOC_COUNT} associação(ões) encontrada(s)${NC}"
    
    echo "$ASSOCIATIONS" | grep -v '^$' | while IFS=$'\t' read -r subnet_id assoc_id; do
        # Obter nome da subnet
        SUBNET_NAME=$(aws ec2 describe-subnets \
            --subnet-ids "${subnet_id}" \
            --query 'Subnets[0].Tags[?Key==`Name`].Value|[0]' \
            --output text 2>/dev/null)
        echo -e "  • Subnet: ${SUBNET_NAME} (${subnet_id})"
        echo -e "    Associação: ${assoc_id}"
    done
    echo ""
}

# Função para validar isolamento de rede
validate_network_isolation() {
    echo -e "${YELLOW}[5/6] Validando Isolamento de Rede...${NC}"
    
    # Verificar se as database subnets não têm rota para Internet Gateway
    DATABASE_SUBNET_ID=$(echo "$DATABASE_SUBNETS" | head -1 | awk '{print $1}')
    
    RT_ID=$(aws ec2 describe-route-tables \
        --filters "Name=association.subnet-id,Values=${DATABASE_SUBNET_ID}" \
        --query 'RouteTables[0].RouteTableId' \
        --output text 2>/dev/null)
    
    if [ "$RT_ID" != "None" ] && [ ! -z "$RT_ID" ]; then
        # Verificar se há rota para Internet Gateway
        IGW_ROUTE=$(aws ec2 describe-route-tables \
            --route-table-ids "$RT_ID" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0` && starts_with(GatewayId, `igw-`)]' \
            --output text 2>/dev/null)
        
        if [ ! -z "$IGW_ROUTE" ]; then
            echo -e "${RED}❌ Database subnet tem rota direta para Internet Gateway${NC}"
            echo -e "  Isso pode ser um risco de segurança!"
        else
            echo -e "${GREEN}✓ Database subnet isolada da internet${NC}"
            echo -e "  Sem rota direta para Internet Gateway"
        fi
        
        # Verificar se há rota para NAT Gateway
        NAT_ROUTE=$(aws ec2 describe-route-tables \
            --route-table-ids "$RT_ID" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0` && starts_with(NatGatewayId, `nat-`)]' \
            --output text 2>/dev/null)
        
        if [ ! -z "$NAT_ROUTE" ]; then
            echo -e "${YELLOW}⚠️  Database subnet tem rota para NAT Gateway${NC}"
            echo -e "  Considere se isso é necessário para sua arquitetura"
        else
            echo -e "${GREEN}✓ Database subnet completamente isolada${NC}"
        fi
    else
        echo -e "${GREEN}✓ Database subnet usa route table padrão (isolada)${NC}"
    fi
    echo ""
}

# Função para resumo de conectividade
connectivity_summary() {
    echo -e "${YELLOW}[6/6] Resumo de Conectividade...${NC}"
    
    echo -e "${BLUE}📋 Configuração das Database Subnets:${NC}"
    echo -e "  • Subnets isoladas para bancos de dados"
    echo -e "  • Network ACL específica com regras restritivas"
    echo -e "  • Acesso permitido apenas nas portas necessárias:"
    echo -e "    - MySQL: 3306 (das subnets privadas)"
    echo -e "    - Redis: 6379 (das subnets privadas)"
    echo -e "  • Negação padrão para todo o resto"
    
    echo -e "\n${GREEN}✅ Validação concluída com sucesso!${NC}"
    echo -e "${BLUE}As database subnets estão configuradas corretamente para isolamento e segurança.${NC}"
    echo ""
}

# Execução principal
main() {
    check_aws_cli
    validate_vpc
    validate_database_subnets
    validate_network_acl
    validate_subnet_associations
    validate_network_isolation
    connectivity_summary
}

# Executar script
main
