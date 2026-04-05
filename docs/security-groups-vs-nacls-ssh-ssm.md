# 🔐 Guia de Segurança: Security Groups vs NACLs e Acesso Seguro SSH/SSM

## 📋 Visão Geral

Este documento aborda as melhores práticas de segurança para acesso a instâncias EC2, comparando Security Groups vs Network ACLs e explicando por que o AWS Systems Manager (SSM) é preferível ao SSH tradicional.

## 🛡️ Security Groups vs Network ACLs (NACLs)

### **Security Groups**

Security Groups são configurações de segurança que você aplica a **Elastic Network Interfaces**.

- **Nível**: Instância EC2 (ENI - Elastic Network Interface)
- **Tipo**: Firewall stateful
- **Comportamento**: Regras de entrada automaticamente permitem resposta de saída
- **Padrão**: Deny all inbound, Allow all outbound
- **Aplicação**: Específico por instância/ENI

**Características Importantes:**

- **Stateful por padrão**: Conexões já estabelecidas não são interrompidas porque você modificou algum componente que, em tese, as bloquearia
- **Apenas liberações**: Toda comunicação não explicitamente liberada é proibida. Mas há um efeito colateral nisso: você não consegue **criar bloqueios**, criar **proibições**, criar **exceções** para regras
- **Limitação crítica**: Se você precisa criar bloqueios, como você faz? Se você precisar interromper todas as sessões pré-existentes, **o que você faz**?

### **Network ACLs**

Network ACLs são configurações de segurança que você aplica a **Subnets**.

- **Nível**: Subnet
- **Tipo**: Firewall stateless
- **Comportamento**: Regras de entrada e saída devem ser configuradas separadamente
- **Padrão**: Allow all (default NACL)
- **Aplicação**: Todas as instâncias da subnet

**Características Importantes:**

- **Stateless**: Cada pacote é avaliado independentemente
- **Permite bloqueios**: NetworkACLs permitem tanto criar bloqueios quanto interromper sessões pré-existentes porque é um recurso **stateless**
- **Controle granular**: Pode bloquear IPs específicos, portas ou protocolos
- **Interrupção de sessões**: Consegue interromper conexões já estabelecidas

### **Quando Usar Cada Um**

| Cenário | Security Groups | NACLs |
|---------|----------------|-------|
| **Controle granular por instância** | ✅ Ideal | ❌ Não adequado |
| **Controle de subnet inteira** | ⚠️ Possível mas trabalhoso | ✅ Ideal |
| **Regras complexas stateful** | ✅ Nativo | ❌ Requer configuração manual |
| **Bloqueio de IPs específicos** | ⚠️ Limitado | ✅ Ideal |
| **Interrupção de sessões ativas** | ❌ Não consegue | ✅ Consegue |
| **Criação de exceções/proibições** | ❌ Não consegue | ✅ Consegue |
| **Defesa em profundidade** | ✅ Primeira camada | ✅ Segunda camada |

## ❓ Perguntas Frequentes: Bloqueios e Interrupção de Sessões

### **Se você precisa criar bloqueios, como você faz?**

**Resposta**: Use **Network ACLs (NACLs)**

```hcl
# Exemplo: Bloquear IP específico em uma subnet
resource "aws_network_acl_rule" "block_malicious_ip" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = "192.168.1.100/32"  # IP malicioso
}
```

**Por que Security Groups não conseguem?**

- Security Groups trabalham apenas com **liberações** (allow rules)
- Não possuem regras de **negação** (deny rules)
- São **stateful** - conexões estabelecidas continuam funcionando

### **Se você precisar interromper todas as sessões pré-existentes, o que você faz?**

**Resposta**: Use **Network ACLs (NACLs)** porque são **stateless**

```hcl
# Exemplo: Bloquear todo tráfego SSH temporariamente
resource "aws_network_acl_rule" "block_ssh_emergency" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 50
  protocol       = "tcp"
  rule_action    = "deny"
  from_port      = 22
  to_port        = 22
  cidr_block     = "0.0.0.0/0"
}
```

**Por que Security Groups não conseguem interromper sessões?**

- São **stateful** - mantêm o estado das conexões
- Conexões já estabelecidas continuam funcionando mesmo após mudança de regras
- Apenas impedem **novas** conexões

### **Cenários Práticos de Uso**

| Cenário | Solução | Ferramenta |
|---------|---------|------------|
| **Bloquear IP malicioso** | NACL com regra deny | Network ACL |
| **Emergência: cortar todas conexões SSH** | NACL bloqueando porta 22 | Network ACL |
| **Permitir apenas IPs específicos** | Security Group com CIDR restrito | Security Group |
| **Bloquear subnet inteira** | NACL com regra deny para CIDR | Network ACL |
| **Controle granular por instância** | Security Group específico | Security Group |

## 🚫 Acesso Seguro às Instâncias via SSH

### **⚠️ O Ideal é que você NÃO acesse suas máquinas Linux via SSH**

**Por quê evitar SSH direto?**

- **Gerenciamento de chaves**: Complexidade de rotação e distribuição
- **Auditoria limitada**: Menos visibilidade sobre ações executadas
- **Exposição de rede**: Necessita porta 22 aberta
- **Risco de comprometimento**: Chaves podem ser expostas ou roubadas

## ✅ AWS Systems Manager (SSM) Session Manager

### **Vantagens do SSM Session Manager**

1. **🔐 Sem Chaves SSH**
   - Não precisa gerenciar key pairs
   - Autenticação via IAM
   - Rotação automática de credenciais

2. **📊 Auditoria Completa**
   - Todos os acessos logados no CloudTrail
   - Histórico de comandos executados
   - Rastreabilidade total

3. **🌐 Conectividade Segura**
   - Conexão via API do serviço SSM
   - Não requer portas abertas (22, 3389)
   - Funciona através de NAT Gateway/Instance

4. **🎯 Controle de Acesso Granular**
   - Permissões via IAM policies
   - Controle por usuário/role
   - Integração com AWS Organizations

### **Como Implementar SSM Session Manager**

#### **1. IAM Role para Instâncias**

```hcl
resource "aws_iam_role" "wordpress_ssm" {
  name_prefix = "${var.project_name}-wordpress-ssm-"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Política AWS gerenciada para SSM
resource "aws_iam_role_policy_attachment" "wordpress_ssm" {
  role       = aws_iam_role.wordpress_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

#### **2. Instance Profile**

```hcl
resource "aws_iam_instance_profile" "wordpress_ssm" {
  name_prefix = "${var.project_name}-wordpress-ssm-"
  role        = aws_iam_role.wordpress_ssm.name
}
```

#### **3. Launch Template com SSM**

```hcl
resource "aws_launch_template" "wordpress" {
  # ... outras configurações
  
  iam_instance_profile {
    name = aws_iam_instance_profile.wordpress_ssm.name
  }
  
  # NÃO especificar key_name para SSH
  # key_name = "..."  # ← Omitir esta linha
}
```

### **Como Usar SSM Session Manager**

#### **Via AWS CLI**

```bash
# Listar instâncias disponíveis
aws ssm describe-instance-information

# Conectar a uma instância específica
aws ssm start-session --target i-1234567890abcdef0

# Executar comando único
aws ssm send-command \
  --instance-ids "i-1234567890abcdef0" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["uptime","df -h"]'
```

#### **Via Console AWS**

1. Acesse **EC2 Console**
2. Selecione a instância
3. Clique em **Connect**
4. Escolha **Session Manager**
5. Clique em **Connect**

## 🔧 Configuração Híbrida (SSH + SSM)

### **Cenário Atual do Projeto**

No projeto Terraform WordPress, temos uma configuração híbrida:

```hcl
# Security Group permite SSH interno
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.vpc_cidr]  # Apenas VPC interna
  description = "SSH interno para troubleshooting"
}
```

**Características:**

- ✅ **SSM habilitado**: Acesso principal recomendado
- ⚠️ **SSH disponível**: Apenas para emergências
- 🔒 **SSH restrito**: Somente da VPC interna (10.0.0.0/16)
- 🚫 **Sem key pair**: SSH não funcional por padrão

### **Recomendação de Uso**

| Situação | Método Recomendado | Justificativa |
|----------|-------------------|---------------|
| **Acesso rotineiro** | SSM Session Manager | Segurança e auditoria |
| **Troubleshooting** | SSM Session Manager | Logs completos |
| **Automação** | SSM Run Command | Escalabilidade |
| **Emergência extrema** | SSH (se configurado) | Último recurso |

## 📚 Recursos Adicionais

### **Documentação Oficial**

- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Getting Started - Create IAM Instance Profile](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-create-iam-instance-profile.html)

### **Vantagens Avançadas do SSM**

- **Logs de auditoria**: Comandos executados não podem ser excluídos
- **Session recording**: Gravação completa de sessões
- **Port forwarding**: Túneis seguros para aplicações
- **Just-in-time access**: Controle temporal de acesso

### **Recursos de Controle de Acesso**

- [AWS Systems Manager Just-in-Time Node Access](https://aws.amazon.com/about-aws/whats-new/2025/04/aws-systems-manager-just-in-time-node-access/)

## 🎯 Conclusão

### **Melhores Práticas**

1. **🔐 Use SSM Session Manager** como método principal de acesso
2. **🛡️ Configure Security Groups** para controle granular por instância
3. **🌐 Use NACLs** para controle de subnet e bloqueio de IPs
4. **🚫 Evite SSH direto** sempre que possível
5. **📊 Monitore acessos** via CloudTrail e CloudWatch

### **Implementação no Projeto**

O projeto Terraform WordPress já implementa essas práticas:

- ✅ SSM habilitado e funcional
- ✅ Security Groups configurados corretamente
- ✅ SSH restrito apenas à VPC interna
- ✅ Auditoria completa via CloudTrail

**Comando para acesso:**

```bash
aws ssm start-session --target $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "cloudpro-vpc-asg" --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' --output text | head -1)
```

---

É importante lembrar que a comunicação com o SSM é feita por meio da rede pública da AWS (o endpoit do SSM ssm.us-east-1.amazonaws.com tem um IP internet)

```bash
host ssm.us-east-1.amazonaws.com
ssm.us-east-1.amazonaws.com has address 13.217.79.129
```

Caso por qualquer razão seja necessário **bloquear** todo tráfego de saída com destino à internet, é necessário criar um Interface Endpoint para  os serviços relevantas, você precisa criar 3 interface endpoitns no mínimo como mostra a documentação oficial do AWS:

- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html)
