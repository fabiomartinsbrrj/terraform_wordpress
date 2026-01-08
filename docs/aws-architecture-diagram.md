<!-- [MermaidChart: 7566cabe-9802-4593-bdce-b5543507b35b] -->
<!-- [MermaidChart: 7566cabe-9802-4593-bdce-b5543507b35b] -->
<!-- [MermaidChart: 7566cabe-9802-4593-bdce-b5543507b35b] -->
<!-- [MermaidChart: 14a48212-bea0-46ec-8723-509048192464] -->
<!-- [MermaidChart: 14a48212-bea0-46ec-8723-509048192464] -->
<!-- [MermaidChart: 14a48212-bea0-46ec-8723-509048192464] -->
# Diagrama da Arquitetura AWS - WordPress Infrastructure

Este diagrama representa todos os recursos AWS implementados no projeto Terraform WordPress, incluindo suas relações e dependências.

## Diagrama Completo da Arquitetura

```mermaid
graph TB
    %% Internet e DNS
    Internet([Internet])
    
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
            ALB[Application Load Balancer<br/>internet-facing<br/>HTTP Listener :80]
            ALBSG[ALB Security Group<br/>HTTP/HTTPS from 0.0.0.0/0<br/>Egress to VPC]
            TG[Target Group<br/>HTTP :80<br/>Health Checks: /]
        end
        
        %% Subnet Privada
        subgraph PrivateAZ1["📍 us-east-1a - Private"]
            PrivSub1[Private Subnet<br/>10.0.0.0/20]
            EC2[WordPress Instance<br/>t3.micro<br/>Amazon Linux 2]
            EC2SG[WordPress Security Group<br/>HTTP/HTTPS from ALB SG<br/>SSH/MySQL from VPC]
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
            RDS[RDS MySQL 8.0.44<br/>t3.micro<br/>Multi-AZ]
            RDSSG[RDS Security Group<br/>MySQL :3306 from WordPress SG]
            DBSubnetGroup[DB Subnet Group<br/>Multi-AZ]
        end
        
        %% Network ACL
        NACL[Network ACL<br/>Database Subnets<br/>Restrictive Rules]
        
        %% Route Tables
        PubRT[Public Route Table<br/>0.0.0.0/0 → IGW]
        PrivRT[Private Route Table<br/>0.0.0.0/0 → NAT Gateway]
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
    
    %% Conexões Internet
    Internet --> IGW
    IGW --> ALB
    
    %% Conexões ALB
    ALB --> TG
    TG --> EC2
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
    EC2 --> RDS
    RDS --> DBSubnetGroup
    DBSubnetGroup --> DBSub1
    DBSubnetGroup --> DBSub2
    NACL --> DBSub1
    NACL --> DBSub2
    
    %% Conexões Security Groups
    EC2SG --> EC2
    RDSSG --> RDS
    EC2SG -.-> ALBSG
    RDSSG -.-> EC2SG
    
    %% Conexões IAM
    IAMRole --> InstanceProfile
    InstanceProfile --> EC2
    RDSRole --> RDS
    
    %% Conexões SSM
    EC2 --> SSM
    IAMRole -.-> SSM
    
    %% Conexões Monitoring
    RDS --> CW
    ALB --> CW
    TG --> CW
    RDSRole -.-> CW
    
    %% Estilos
    classDef internet fill:#ff9999,stroke:#333,stroke-width:2px
    classDef vpc fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef public fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
    classDef private fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef database fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef security fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef iam fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef monitoring fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    
    class Internet internet
    class VPC vpc
    class PubSub1,PubSub2,NAT1,NAT2,IGW,ALB,TG public
    class PrivSub1,EC2 private
    class DBSub1,DBSub2,RDS,DBSubnetGroup database
    class ALBSG,EC2SG,RDSSG,NACL security
    class IAM,IAMRole,InstanceProfile,RDSRole iam
    class CW,Monitoring monitoring
```

## Legenda dos Recursos

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
- **Target Group**: HTTP port 80 com health checks
- **Listener**: HTTP (porta 80) com forward para WordPress

### 🖥️ **Compute**

- **EC2 Instance**: WordPress t3.micro na subnet privada
- **User Data**: Instalação automática WordPress + WP-CLI
- **EBS**: Volume GP3 20GB criptografado

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

### 📊 **Monitoring**

- **CloudWatch**: Métricas ALB, RDS e target health
- **Enhanced Monitoring**: RDS performance insights

## Fluxo de Tráfego

1. **Internet** → **Internet Gateway** → **ALB** (subnets públicas)
2. **ALB** → **Target Group** → **WordPress Instance** (subnet privada)
3. **WordPress** → **RDS MySQL** (subnets database isoladas)
4. **WordPress** → **NAT Gateway** → **Internet** (updates, APIs)

## Issues Implementadas

- ✅ **Issue #1**: IAM Role SSM
- ✅ **Issue #3**: Security Groups  
- ✅ **Issue #4**: RDS MySQL
- ✅ **Issue #6**: Application Load Balancer

## Próximas Expansões

- 🚀 **Issue #13**: HTTPS/SSL (ACM)
- 🚀 **Issue #15**: Route 53 DNS
- 🚀 **Issue #16**: AWS WAF
- 🚀 **Issue #7**: Auto Scaling Group
- 🚀 **Issue #2**: EFS (Arquivos Compartilhados)

---

**Gerado automaticamente pelo projeto Terraform WordPress Infrastructure**
