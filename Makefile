# Makefile para validação da infraestrutura WordPress
# Autor: Terraform WordPress Project
# Descrição: Scripts de validação para EC2, RDS, SSM e WordPress

.PHONY: help validate-all validate-ssm validate-rds validate-wordpress validate-logs validate-alb clean

# Variáveis
SCRIPTS_DIR = scripts/validation
TERRAFORM_DIR = .

# Target padrão
help: ## Mostra esta mensagem de ajuda
	@echo "🚀 Makefile - Validação WordPress Infrastructure"
	@echo ""
	@echo "Targets disponíveis:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "📋 Exemplos de uso:"
	@echo "  make validate-all     # Executa todas as validações"
	@echo "  make validate-ssm     # Testa apenas Session Manager"
	@echo "  make validate-rds     # Testa apenas conectividade RDS"
	@echo ""

validate-all: ## Executa todas as validações (SSM, RDS, WordPress, ALB, Logs)
	@echo "🎯 Executando todas as validações..."
	@echo ""
	@$(MAKE) validate-ssm
	@echo ""
	@$(MAKE) validate-rds
	@echo ""
	@$(MAKE) validate-alb
	@echo ""
	@$(MAKE) validate-wordpress
	@echo ""
	@echo "✅ Todas as validações concluídas!"

validate-ssm: ## Valida acesso via Session Manager (Issue #1)
	@echo "🔍 Validando Session Manager..."
	@if [ ! -f $(SCRIPTS_DIR)/validate_ssm_access.sh ]; then \
		echo "❌ Script validate_ssm_access.sh não encontrado!"; \
		exit 1; \
	fi
	@chmod +x $(SCRIPTS_DIR)/validate_ssm_access.sh
	@$(SCRIPTS_DIR)/validate_ssm_access.sh

validate-rds: ## Testa conectividade com RDS MySQL (Issue #4)
	@echo "🔍 Testando conectividade RDS..."
	@if [ ! -f $(SCRIPTS_DIR)/simple_rds_test.sh ]; then \
		echo "❌ Script simple_rds_test.sh não encontrado!"; \
		exit 1; \
	fi
	@chmod +x $(SCRIPTS_DIR)/simple_rds_test.sh
	@$(SCRIPTS_DIR)/simple_rds_test.sh

validate-wordpress: validate-logs ## Alias para validate-logs (compatibilidade)

validate-alb: ## Testa conectividade através do ALB (Issue #6)
	@echo "🔍 Validando Application Load Balancer..."
	@if [ ! -f $(SCRIPTS_DIR)/validate_alb_access.sh ]; then \
		echo "❌ Script validate_alb_access.sh não encontrado!"; \
		exit 1; \
	fi
	@chmod +x $(SCRIPTS_DIR)/validate_alb_access.sh
	@$(SCRIPTS_DIR)/validate_alb_access.sh

validate-logs: ## Verifica logs e status da instância WordPress
	@echo "🔍 Verificando logs do WordPress..."
	@if [ ! -f $(SCRIPTS_DIR)/check_wordpress_logs.sh ]; then \
		echo "❌ Script check_wordpress_logs.sh não encontrado!"; \
		exit 1; \
	fi
	@chmod +x $(SCRIPTS_DIR)/check_wordpress_logs.sh
	@$(SCRIPTS_DIR)/check_wordpress_logs.sh

# Targets de infraestrutura Terraform
terraform-init: ## Inicializa Terraform
	@echo "🔧 Inicializando Terraform..."
	@terraform init

terraform-plan: ## Executa terraform plan
	@echo "📋 Executando Terraform Plan..."
	@terraform plan -var-file=./environment/prod/terraform.tfvars

terraform-apply: ## Executa terraform apply
	@echo "🚀 Executando Terraform Apply..."
	@terraform apply -var-file=./environment/prod/terraform.tfvars -auto-approve

terraform-destroy: ## Executa terraform destroy
	@echo "💥 Executando Terraform Destroy..."
	@terraform destroy -var-file=./environment/prod/terraform.tfvars -auto-approve

# Targets de desenvolvimento
dev-setup: terraform-init terraform-apply ## Setup completo para desenvolvimento
	@echo "🎉 Setup de desenvolvimento concluído!"
	@echo "Execute 'make validate-all' para verificar se tudo está funcionando"

dev-validate: validate-all ## Alias para validate-all (desenvolvimento)

# Targets de limpeza
clean: ## Remove arquivos temporários e logs
	@echo "🧹 Limpando arquivos temporários..."
	@find . -name "*.log" -type f -delete 2>/dev/null || true
	@find . -name ".terraform.lock.hcl" -type f -delete 2>/dev/null || true
	@rm -rf .terraform/ 2>/dev/null || true
	@echo "✅ Limpeza concluída!"

# Targets de informação
status: ## Mostra status da infraestrutura
	@echo "📊 Status da Infraestrutura WordPress:"
	@echo ""
	@echo "🔍 Instâncias EC2:"
	@aws ec2 describe-instances \
		--filters "Name=tag:Name,Values=*wordpress*" "Name=instance-state-name,Values=running,stopped" \
		--query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
		--output table 2>/dev/null || echo "❌ Erro ao consultar EC2"
	@echo ""
	@echo "🔍 Instâncias RDS:"
	@aws rds describe-db-instances \
		--query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]' \
		--output table 2>/dev/null || echo "❌ Erro ao consultar RDS"

# Targets de troubleshooting
debug-ssm: ## Debug detalhado do Session Manager
	@echo "🐛 Debug Session Manager..."
	@aws ssm describe-instance-information \
		--query 'InstanceInformationList[].[InstanceId,PingStatus,LastPingDateTime]' \
		--output table 2>/dev/null || echo "❌ Erro ao consultar SSM"

debug-rds: ## Debug detalhado do RDS
	@echo "🐛 Debug RDS..."
	@aws rds describe-db-instances \
		--query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,VpcSecurityGroups[].Status,Endpoint.Address,Endpoint.Port]' \
		--output table 2>/dev/null || echo "❌ Erro ao consultar RDS"

# Target especial para Issues do GitHub
validate-issue-1: validate-ssm ## Valida Issue #1 - IAM Role SSM
	@echo "✅ Issue #1 - IAM Role SSM validada!"

validate-issue-4: validate-rds ## Valida Issue #4 - RDS MySQL
	@echo "✅ Issue #4 - RDS MySQL validada!"

validate-issue-6: validate-alb ## Valida Issue #6 - Application Load Balancer
	@echo "✅ Issue #6 - Application Load Balancer validada!"

# Informações do projeto
info: ## Mostra informações do projeto
	@echo "📋 Informações do Projeto WordPress"
	@echo "=================================="
	@echo "Projeto: Terraform WordPress Infrastructure"
	@echo "Issues Implementadas: #1 (SSM), #4 (RDS)"
	@echo "Scripts de Validação: $(shell ls -1 $(SCRIPTS_DIR)/*.sh 2>/dev/null | wc -l)"
	@echo "Terraform Version: $(shell terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo 'N/A')"
	@echo "AWS CLI Version: $(shell aws --version 2>/dev/null || echo 'N/A')"
	@echo ""
	@echo "📁 Estrutura de Scripts:"
	@ls -la $(SCRIPTS_DIR)/ 2>/dev/null || echo "❌ Diretório de scripts não encontrado"
