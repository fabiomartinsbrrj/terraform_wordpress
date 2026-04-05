# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform project that provisions a complete AWS infrastructure for hosting WordPress. All resources are defined in a flat structure (no modules) at the repo root, organized by responsibility into separate `.tf` files.

## Common Commands

### Terraform

```bash
# Initialize with remote S3 backend
terraform init -backend-config=environment/prod/backend.tfvars

# Plan / Apply against prod
terraform plan -var-file=./environment/prod/terraform.tfvars
terraform apply -var-file=./environment/prod/terraform.tfvars

# Format check (run before PRs; CI enforces this)
terraform fmt -check -recursive

# Validate syntax
terraform validate

# Safe destroy (handles RDS deletion protection)
./scripts/safe_destroy.sh
```

### Validation (Make targets)

```bash
make validate-all        # All validations
make validate-ssm        # Session Manager access (Issue #1)
make validate-rds        # RDS MySQL connectivity (Issue #4)
make validate-alb        # Application Load Balancer (Issue #6)
make validate-asg        # Auto Scaling Group (Issue #7)
make validate-route53    # Route 53 DNS (Issue #15)
make validate-wordpress  # WordPress logs / status
make status              # Show EC2 and RDS state via AWS CLI
```

### Debug

```bash
make debug-ssm   # Show SSM instance registration status
make debug-rds   # Show RDS endpoints and security group state
```

## Architecture

### Network Layout

- **VPC**: `10.0.0.0/16` + secondary CIDR `100.64.0.0/16`
- **Public subnets** (`10.0.48.0/24` us-east-1a, `10.0.49.0/24` us-east-1b): ALB and NAT Gateways
- **Private subnet** (`10.0.0.0/20` us-east-1a): ASG WordPress instances (no public IPs)
- **Database subnets** (`10.0.51.0/24` us-east-1a, `10.0.52.0/24` us-east-1b): RDS Multi-AZ (isolated, Network ACL enforced)

### Traffic Flow

Internet → Route 53 (`wordpress.fabiodev.com`) → ALB (internet-facing, 2 public subnets) → Target Group → ASG instances (private subnet) → RDS MySQL / EFS

Instance access is via **SSM Session Manager only** — no SSH keys, no bastion host.

### Key Resource Relationships

- `asg.tf` references `aws_security_group.wordpress_basic` (defined in `ec2.tf`), `aws_iam_instance_profile.wordpress_ssm` (in `iam.tf`), `aws_lb_target_group.wordpress` (in `alb.tf`), and `aws_subnet.private` (in `private_subnets.tf`)
- `user_data.tpl` is rendered as a templatefile in `asg.tf`; it fetches DB credentials from SSM Parameter Store at boot, installs WordPress, and mounts EFS at `/var/www/html`
- EFS (`efs.tf`) provides shared WordPress file storage across all ASG instances via an access point (uid/gid 33 — www-data)
- SSM Parameter Store (`ssm.tf`) holds DB username, password (SecureString), and RDS endpoint; EC2 IAM role has read access

### CI/CD

GitHub Actions (`.github/workflows/terraform-pr.yml`) runs on PRs targeting `main`/`master` when `.tf` or `.tfvars` files change. It runs `fmt -check`, `validate`, and `plan`, then posts the plan as a PR comment. Variables come from GitHub Actions vars/secrets (not committed tfvars). The `TF_VAR_db_password` secret must be set in the repository.

## Important AWS Constraints

- **ALB requires ≥ 2 public subnets in different AZs** — adding a second public subnet is mandatory, not optional.
- **RDS Multi-AZ requires ≥ 2 database subnets in different AZs**.
- The `db_password` variable has no default and must always be supplied (either via tfvars or `TF_VAR_db_password`).

## Remote State

State is stored in S3: bucket `linuxtips-cloudbr2025-eks-state-files-foxbrrj`, key `wordpress/vpc/prod/state`, region `us-east-1`. The backend config is in `environment/prod/backend.tfvars`.

## Files to Know

| File | Purpose |
|------|---------|
| `variables.tf` | All input variables with types and defaults |
| `outputs.tf` | All resource outputs (IDs, ARNs, DNS names) |
| `user_data.tpl` | EC2 bootstrap: installs Apache/PHP/WordPress, mounts EFS, pulls creds from SSM |
| `environment/prod/terraform.tfvars` | Prod variable values (subnets, CIDRs, db creds) |
| `DESTROY_GUIDE.md` | Steps to safely destroy RDS with deletion protection |
