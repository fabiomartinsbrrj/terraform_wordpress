<!-- [MermaidChart: 7566cabe-9802-4593-bdce-b5543507b35b] -->
<!-- [MermaidChart: 7566cabe-9802-4593-bdce-b5543507b35b] -->
<!-- [MermaidChart: 7566cabe-9802-4593-bdce-b5543507b35b] -->
<!-- [MermaidChart: 14a48212-bea0-46ec-8723-509048192464] -->
<!-- [MermaidChart: 14a48212-bea0-46ec-8723-509048192464] -->
<!-- [MermaidChart: 14a48212-bea0-46ec-8723-509048192464] -->
# Diagrama da Arquitetura AWS - WordPress Infrastructure

Este diagrama representa todos os recursos AWS implementados no projeto Terraform WordPress, incluindo suas relações e dependências. **Agora com EFS para compartilhamento de arquivos e Auto Scaling Group para escalabilidade automática**, além do Route 53 DNS personalizado para acesso profissional via `wordpress.fabiodev.com`.

## Diagrama Completo da Arquitetura

```mermaid
graph TB
    %% Internet e Route 53 DNS
    Internet([Internet])
    
    %% Route 53 DNS Layer
    subgraph Route53["🌐 Route 53 DNS"]
        HostedZone["Hosted Zone<br/>fabiodev.com<br/>$0.50/mês"]
        ARecord["A Record Alias<br/>wordpress.fabiodev.com<br/>to ALB"]
        CNAMERecord["CNAME Record<br/>www.wordpress.fabiodev.com<br/>to wordpress.fabiodev.com"]
        HealthCheck1["Health Check<br/>wordpress.fabiodev.com<br/>HTTP port 80"]
        HealthCheck2["Health Check<br/>www.wordpress.fabiodev.com<br/>HTTP port 80"]
    end
    
    %% VPC e Networking
    subgraph VPC["🌐 VPC (10.0.0.0/16 + 100.64.0.0/16)"]
        
        %% Internet Gateway
        IGW[Internet Gateway<br/>igw-main]
        
        %% Subnets Públicas
        subgraph PublicAZ1["📍 us-east-1a - Public"]
            PubSub1[Public Subnet<br/>10.0.48.0/24]
            NAT1[NAT Gateway 1<br/>+ Elastic IP]
        end
        
        subgraph PublicAZ2["📍 us-east-1b - Public"]
            PubSub2[Public Subnet<br/>10.0.49.0/24]
            NAT2[NAT Gateway 2<br/>+ Elastic IP]
        end
        
        %% Application Load Balancer
        subgraph ALBLayer["🔄 Load Balancing Layer"]
            ALB["Application Load Balancer<br/>internet-facing<br/>HTTP Listener port 80<br/>DNS wordpress.fabiodev.com"]
            ALBSG["ALB Security Group<br/>HTTP/HTTPS from 0.0.0.0/0<br/>Egress to VPC"]
            TG["Target Group<br/>HTTP port 80<br/>Health Checks path /"]
        end
        
        %% Subnet Privada com Auto Scaling Group
        subgraph PrivateAZ1["📍 us-east-1a - Private"]
            PrivSub1[Private Subnet<br/>10.0.0.0/20]
            ASG[Auto Scaling Group<br/>Min: 1, Max: 3, Desired: 2<br/>Launch Template t3.micro]
            LT[Launch Template<br/>Amazon Linux 2<br/>WordPress + EFS mount]
            EC2SG[WordPress Security Group<br/>HTTP/HTTPS from ALB SG<br/>SSH/MySQL from VPC<br/>NFS to EFS]
        end
        
        %% EFS Layer
        subgraph EFSLayer["📁 EFS - Elastic File System"]
            EFS["EFS File System<br/>General Purpose<br/>Provisioned 10 MiB/s<br/>Encrypted"]
            EFSSG["EFS Security Group<br/>NFS port 2049<br/>from Private Subnets"]
            MountTarget["Mount Target<br/>Multi-AZ<br/>us-east-1a"]
            AccessPoint["Access Point<br/>WordPress<br/>uid/gid 33 (www-data)"]
            BackupPolicy["Backup Policy<br/>Daily backup<br/>35 days retention"]
        end
        
        %% CloudWatch Scaling
        subgraph ScalingLayer["📊 Auto Scaling & Monitoring"]
            CPUHigh["CPU High Alarm<br/>>70% for 4 minutes<br/>Scale Up Policy"]
            CPULow["CPU Low Alarm<br/><30% for 4 minutes<br/>Scale Down Policy"]
            ScaleUp["Scale Up Policy<br/>+1 instance<br/>300s cooldown"]
            ScaleDown["Scale Down Policy<br/>-1 instance<br/>300s cooldown"]
        end
        
        %% Subnets Database
        subgraph DatabaseAZ1["📍 us-east-1a - Database"]
            DBSub1[Database Subnet<br/>10.0.51.0/24]
        end
        
        subgraph DatabaseAZ2["📍 us-east-1b - Database"]
            DBSub2[Database Subnet<br/>10.0.52.0/24]
        end
        
        %% RDS
        subgraph RDSLayer["🗄️ Database Layer"]
            RDS["RDS MySQL 8.0.44<br/>t3.micro<br/>Multi-AZ"]
            RDSSG["RDS Security Group<br/>MySQL port 3306 from WordPress SG"]
            DBSubnetGroup["DB Subnet Group<br/>Multi-AZ"]
        end
        
        %% Network ACL
        NACL[Network ACL<br/>Database Subnets<br/>Restrictive Rules]
        
        %% Route Tables
        PubRT["Public Route Table<br/>0.0.0.0/0 to IGW"]
        PrivRT["Private Route Table<br/>0.0.0.0/0 to NAT Gateway"]
    end
    
    %% IAM Resources
    subgraph IAM["🔐 IAM Resources"]
        IAMRole[WordPress SSM Role<br/>SSM + Parameter Store]
        InstanceProfile[Instance Profile<br/>WordPress SSM]
        RDSRole[RDS Monitoring Role<br/>Enhanced Monitoring]
    end
    
    %% SSM Parameter Store
    subgraph SSM["📋 SSM Parameter Store"]
        SSMUser[DB Username<br/>SecureString]
        SSMPass[DB Password<br/>SecureString]
        SSMEndpoint[DB Endpoint<br/>String]
    end
    
    %% CloudWatch (implícito)
    subgraph Monitoring["📊 Monitoring"]
        CW[CloudWatch<br/>RDS Enhanced Monitoring<br/>ALB Metrics<br/>Target Health]
    end
    
    %% Conexões Route 53 DNS
    Internet --> Route53
    HostedZone --> ARecord
    HostedZone --> CNAMERecord
    ARecord --> ALB
    CNAMERecord --> ARecord
    HealthCheck1 --> ALB
    HealthCheck2 --> ALB
    
    %% Conexões Internet
    Route53 --> IGW
    IGW --> ALB
    
    %% Conexões ALB e ASG
    ALB --> TG
    TG --> ASG
    ASG --> LT
    ALB -.-> ALBSG
    
    %% Conexões Networking
    IGW --> PubSub1
    IGW --> PubSub2
    PubSub1 --> NAT1
    PubSub2 --> NAT2
    NAT1 --> PrivSub1
    NAT2 --> PrivSub1
    
    %% Conexões Route Tables
    PubRT --> PubSub1
    PubRT --> PubSub2
    PrivRT --> PrivSub1
    
    %% Conexões Database
    ASG --> RDS
    RDS --> DBSubnetGroup
    DBSubnetGroup --> DBSub1
    DBSubnetGroup --> DBSub2
    NACL --> DBSub1
    NACL --> DBSub2
    
    %% Conexões EFS
    ASG --> EFS
    EFS --> MountTarget
    EFS --> AccessPoint
    EFS --> BackupPolicy
    EFS -.-> EFSSG
    MountTarget --> PrivSub1
    
    %% Conexões Auto Scaling
    CPUHigh --> ScaleUp
    CPULow --> ScaleDown
    ScaleUp --> ASG
    ScaleDown --> ASG
    ASG --> CPUHigh
    ASG --> CPULow
    
    %% Conexões Security Groups
    EC2SG --> ASG
    EFSSG --> EFS
    RDSSG --> RDS
    EC2SG -.-> ALBSG
    EC2SG -.-> EFSSG
    RDSSG -.-> EC2SG
    
    %% Conexões IAM
    IAMRole --> InstanceProfile
    InstanceProfile --> LT
    RDSRole --> RDS
    
    %% Conexões SSM
    ASG --> SSM
    IAMRole -.-> SSM
    
    %% Conexões Monitoring
    RDS --> CW
    ALB --> CW
    TG --> CW
    HealthCheck1 --> CW
    HealthCheck2 --> CW
    RDSRole -.-> CW
    
    %% Estilos
    classDef internet fill:#ff9999,stroke:#333,stroke-width:2px
    classDef route53 fill:#ffd54f,stroke:#f57f17,stroke-width:2px
    classDef vpc fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef public fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
    classDef private fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef database fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef security fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef iam fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef monitoring fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    
    class Internet internet
    class Route53,HostedZone,ARecord,CNAMERecord,HealthCheck1,HealthCheck2 route53
    class VPC vpc
    class PubSub1,PubSub2,NAT1,NAT2,IGW,ALB,TG public
    class PrivSub1,ASG,LT private
    class EFS,EFSSG,MountTarget,AccessPoint,BackupPolicy database
    class CPUHigh,CPULow,ScaleUp,ScaleDown,ScalingLayer monitoring
    class DBSub1,DBSub2,RDS,DBSubnetGroup database
    class ALBSG,EC2SG,RDSSG,NACL security
    class IAM,IAMRole,InstanceProfile,RDSRole iam
    class CW,Monitoring monitoring
```

## Legenda dos Recursos

### 🌐 **Route 53 DNS (Issue #15)**

- **Hosted Zone**: `fabiodev.com` com configuração completa ($0.50/mês)
- **Registro A (Alias)**: `wordpress.fabiodev.com` → ALB
- **Registro CNAME**: `www.wordpress.fabiodev.com` → `wordpress.fabiodev.com`
- **Health Checks**: Monitoramento HTTP ativo ($0.50/mês cada)
- **Propagação Global**: DNS funcionando em servidores públicos
- **Name Servers**: 4 name servers AWS configurados

### 🌐 **Networking (VPC)**

- **VPC**: Rede virtual principal com CIDRs `10.0.0.0/16` + `100.64.0.0/16`
- **Internet Gateway**: Acesso à internet para subnets públicas
- **NAT Gateways**: 2 NAT Gateways para alta disponibilidade
- **Elastic IPs**: IPs públicos fixos para NAT Gateways

### 📍 **Subnets**

- **Public Subnets**: 2 subnets em AZs diferentes para ALB e NAT Gateways
- **Private Subnet**: 1 subnet para instâncias WordPress (isoladas)
- **Database Subnets**: 2 subnets isoladas para RDS Multi-AZ

### 🔄 **Load Balancing**

- **Application Load Balancer**: Internet-facing, distribuído em 2 AZs
- **DNS Personalizado**: Acessível via `wordpress.fabiodev.com`
- **Target Group**: HTTP port 80 com health checks
- **Listener**: HTTP (porta 80) com forward para WordPress
- **Múltiplos Acessos**: ALB direto + domínio personalizado

### 🖥️ **Compute & Auto Scaling (Issue #7)**

- **Auto Scaling Group**: Min 1, Max 3, Desired 2 instâncias
- **Launch Template**: AMI Amazon Linux 2, t3.micro, configuração WordPress
- **Health Checks**: ELB + EC2 com grace period de 300s
- **Scaling Policies**: Scale up (CPU >70%), Scale down (CPU <30%)
- **CloudWatch Alarms**: Monitoramento CPU com períodos de 2 minutos
- **Target Group Integration**: Registro automático no ALB
- **Multi-AZ Distribution**: Instâncias distribuídas em múltiplas AZs
- **User Data**: Instalação automática WordPress + WP-CLI + EFS mount
- **EBS**: Volume GP3 20GB criptografado por instância

### 📁 **Shared Storage (Issue #2)**

- **EFS File System**: Sistema de arquivos compartilhado para WordPress
- **Performance Mode**: General Purpose (baixa latência, até 7000 ops/sec)
- **Throughput Mode**: Provisioned (10 MiB/s garantido)
- **Encryption**: Habilitada em repouso com KMS
- **Mount Targets**: Distribuídos em múltiplas AZs para alta disponibilidade
- **Access Point**: Configurado para WordPress (uid/gid 33 - www-data)
- **Backup Policy**: Backup automático diário com retenção de 35 dias
- **Lifecycle Policy**: Transição para IA após 30 dias (otimização de custos)
- **Security Group**: Porta 2049 (NFS) restrita às subnets privadas

### 🗄️ **Database**

- **RDS MySQL**: 8.0.44 t3.micro com Multi-AZ
- **Enhanced Monitoring**: Monitoramento detalhado habilitado
- **Backup**: Retenção 7 dias, janela configurada
- **Encryption**: Storage criptografado

### 🔐 **Security**

- **Security Groups**: ALB, WordPress e RDS com regras específicas
- **Network ACL**: Controle restritivo para subnets database
- **IAM Roles**: WordPress SSM e RDS monitoring

### 📋 **Configuration Management**

- **SSM Parameter Store**: Credenciais DB criptografadas
- **Instance Profile**: Acesso seguro aos parâmetros

### 📊 **Monitoring & Auto Scaling**

- **CloudWatch**: Métricas ALB, RDS, ASG e target health
- **CPU Alarms**: High (>70%) e Low (<30%) com 2 períodos de 2 minutos
- **Scaling Policies**: SimpleScaling com cooldown de 300s
- **ASG Metrics**: GroupMinSize, GroupMaxSize, GroupDesiredCapacity
- **Route 53 Health Checks**: Monitoramento DNS ativo
- **Enhanced Monitoring**: RDS performance insights
- **DNS Monitoring**: Status de propagação e resolução
- **EFS Metrics**: Throughput, IOPS, storage utilization

## Fluxo de Tráfego

### **🎯 Fluxo Principal (Route 53 + Auto Scaling)**

1. **Internet** → **Route 53 DNS** → **wordpress.fabiodev.com**
2. **DNS Resolution** → **ALB** (subnets públicas)
3. **ALB** → **Target Group** → **Auto Scaling Group** (2-3 instâncias)
4. **ASG Instances** → **EFS** (arquivos compartilhados via NFS)
5. **ASG Instances** → **RDS MySQL** (subnets database isoladas)
6. **ASG Instances** → **NAT Gateway** → **Internet** (updates, APIs)
7. **CloudWatch** → **CPU Alarms** → **Scaling Policies** → **ASG**

### **🔄 Fluxo Alternativo (ALB Direto)**

1. **Internet** → **Internet Gateway** → **ALB** (subnets públicas)
2. **ALB** → **Target Group** → **Auto Scaling Group** (instâncias healthy)

### **📊 Monitoramento e Scaling**

1. **Route 53 Health Checks** → **ALB** → **CloudWatch**
2. **ALB Metrics** → **CloudWatch**
3. **ASG CPU Metrics** → **CloudWatch Alarms** → **Scaling Policies**
4. **RDS Enhanced Monitoring** → **CloudWatch**
5. **EFS Performance Metrics** → **CloudWatch**

## Issues Implementadas

- ✅ **Issue #1**: IAM Role SSM
- ✅ **Issue #2**: EFS (Arquivos Compartilhados)
- ✅ **Issue #3**: Security Groups  
- ✅ **Issue #4**: RDS MySQL
- ✅ **Issue #6**: Application Load Balancer
- ✅ **Issue #7**: Auto Scaling Group + Launch Template
- ✅ **Issue #15**: Route 53 DNS Personalizado

## Próximas Expansões

- 🚀 **Issue #13**: HTTPS/SSL (ACM)
- 🚀 **Issue #20**: Replicação Cross-Region para EFS
- 🚀 **Issue #16**: AWS WAF
- 🚀 **CloudWatch Dashboards**: Monitoramento avançado
- 🚀 **ElastiCache**: Cache Redis/Memcached

## 💰 Custos Mensais Atualizados

### **Recursos Ativos**

- **Auto Scaling Group**: ~$17/mês (2x t3.micro)
- **EFS**: ~$3/mês (1GB + provisioned throughput)
- **RDS t3.micro**: ~$15/mês
- **ALB**: ~$16/mês
- **NAT Gateways**: ~$45/mês (2x)
- **Route 53 Hosted Zone**: $0.50/mês
- **Route 53 Health Checks**: $1/mês (2x)
- **EBS GP3 20GB**: ~$4/mês (2x instâncias)
- **CloudWatch**: ~$2/mês (detailed monitoring + alarms)

### **Total Estimado**: ~$103.50/mês

### **Custos Anuais**

- **Domínio fabiodev.com**: $12/ano
- **Infraestrutura**: ~$1,242/ano
- **Total**: ~$1,254/ano

## 🌐 URLs de Acesso

### **Principal (Route 53)**

- ✅ `http://wordpress.fabiodev.com`
- ✅ `http://www.wordpress.fabiodev.com`

### **Backup (ALB Direto)**

- ✅ `http://cloudpro-vpc-alb-*.us-east-1.elb.amazonaws.com`

## 🧪 Validação

### **Comandos de Teste**

```bash
# Validação completa
make validate-all

# Validação Route 53 específica
make validate-route53
make validate-issue-15

# Testes DNS manuais
dig wordpress.fabiodev.com
curl -I http://wordpress.fabiodev.com
```

---

**Gerado automaticamente pelo projeto Terraform WordPress Infrastructure**
