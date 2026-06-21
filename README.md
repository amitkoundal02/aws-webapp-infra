# Auto-Scaling Web Application Infrastructure with Full Observability

![AWS](https://img.shields.io/badge/AWS-FF9900?style=flat-square&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-844FBA?style=flat-square&logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat-square&logo=ansible&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)
![GitHub Copilot](https://img.shields.io/badge/GitHub%20Copilot-010101?style=flat-square&logo=github&logoColor=white)

## Overview

Production-pattern AWS infrastructure built with Terraform (5 modules) and configured with Ansible. Features auto-scaling EC2 tier, managed RDS MySQL, Lambda-based RDS monitoring with SNS alerting, and Prometheus/Grafana observability stack. Built using GitHub Copilot for AI-assisted code generation with manual review.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         INTERNET                             │
└────────────────────────────┬────────────────────────────────┘
                             │
                          ┌──▼──┐
                          │ ALB │ (Port 80)
                          └──┬──┘
                   ┌──────────┴──────────┐
         ┌────────▼────────┐  ┌────────▼────────┐
         │  Public SN-AZ-a │  │  Public SN-AZ-b │
         │  ┌────────────┐ │  │ ┌────────────┐ │
         │  │ EC2 ASG    │ │  │ │ EC2 ASG    │ │
         │  │ t2.micro   │ │  │ │ t2.micro   │ │
         │  │ Apache 80  │ │  │ │ Apache 80  │ │
         │  │ NodeExp    │ │  │ │ NodeExp    │ │
         │  └─────┬──────┘ │  │ └─────┬──────┘ │
         └────────┼────────┘  └───────┼────────┘
                  │                   │
         ┌────────▼─────────────────┬─┘
         │                          │
         │ ┌────────────────────────▼──────────────────────┐
         │ │        VPC 10.0.0.0/16                       │
         │ │                                               │
         │ │ ┌──────────────────────────────────────────┐ │
         │ │ │   Private Subnets (RDS placement)        │ │
         │ │ │  ┌────────────────┐ ┌────────────────┐  │ │
         │ │ │  │ Private SN-a   │ │ Private SN-b   │  │ │
         │ │ │  └────────────────┘ └────────────────┘  │ │
         │ │ │                                          │ │
         │ │ │     ┌────────────────────────────┐      │ │
         │ │ │     │ RDS MySQL (Primary)        │      │ │
         │ │ │     │ db.t3.micro single-AZ      │      │ │
         │ │ │     │ Port 3306 (Private)        │      │ │
         │ │ │     │ 20GB storage               │      │ │
         │ │ │     │ (DB Subnet Group)          │      │ │
         │ │ │     └────────────────────────────┘      │ │
         │ │ └──────────────────────────────────────────┘ │
         │ └──────────────────────────────────────────────┘
         │
┌────────▼────────────────────────────────────────┐
│         AWS EventBridge (every 5 min)            │
│         └─► Lambda (RDS Storage Monitor)         │
│             └─► CloudWatch Metrics               │
│                 └─► SNS Email Alert              │
│                     (storage < 5GB)              │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│       MONITORING (Separate EC2)                  │
│ ┌───────────────────────────────────────────┐   │
│ │ Prometheus (port 9090)                   │   │
│ │ - scrapes all instances on port 9100     │   │
│ │ - retention 15 days                      │   │
│ └───────────────────────────────────────────┘   │
│ ┌───────────────────────────────────────────┐   │
│ │ Grafana (port 3000)                      │   │
│ │ - connects to Prometheus datasource      │   │
│ │ - custom dashboards for EC2/RDS metrics  │   │
│ └───────────────────────────────────────────┘   │
│ ┌───────────────────────────────────────────┐   │
│ │ Node Exporter (port 9100)                │   │
│ │ - system metrics (CPU, mem, disk, net)   │   │
│ └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## What This Provisions

- **Network**: VPC 10.0.0.0/16 with 4 subnets (2 public, 2 private) across 2 AZs (ap-south-1a, ap-south-1b)
- **Internet Gateway**: Direct internet access for public subnets (no NAT Gateway - cost savings)
- **Application Load Balancer**: Health checks every 30s, 200 response on `/health` endpoint
- **Auto Scaling Group**: Min 1, Max 2 EC2 t2.micro instances, scale-out at 70% CPU for 2 minutes
- **RDS MySQL**: Version 8.0, db.t3.micro, 20GB gp2 storage, single-AZ (no backup redundancy in this lab)
- **Lambda Monitor**: Python 3.12, scheduled every 5 minutes via EventBridge, sends SNS alert when RDS storage below 5GB
- **SNS Email Alert**: Sends email to configured address on low storage events
- **Prometheus & Grafana**: Installed via Ansible on separate monitoring EC2 instance
- **Node Exporter**: Installed on all EC2 instances for system metrics collection
- **Terraform State Backend**: S3 + DynamoDB for remote state and locking
- **IAM Instance Profiles**: EC2 instances use IAM roles (no hardcoded credentials, least privilege policies)
- **Security Groups**: Layered SG rules, ALB only exposed to internet on port 80
- **Resource Tags**: All resources tagged with `Project`, `Environment`, `ManagedBy`

## Prerequisites

1. **AWS Account**: ap-south-1 region
   ```bash
   aws configure
   ```

2. **Terraform >= 1.5**
   ```bash
   terraform --version
   ```

3. **S3 Bucket** for Terraform state
   ```bash
   aws s3 mb s3://aws-webapp-infra-remote-state --region ap-south-1
   ```

4. **DynamoDB Table** for state locking
   ```bash
   aws dynamodb create-table \
     --table-name aws-webapp-infra-state-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region ap-south-1
   ```

5. **SSH Key Pair** — Convert existing PPK to PEM:

   On Windows using PuTTYgen:
   - Open PuTTYgen
   - Load your instance_key.ppk file
   - Go to Conversions → Export OpenSSH key
   - Save as instance_key.pem

   Copy PEM to RHEL VM:
   ```bash
   scp instance_key.pem user@RHEL_VM_IP:~/.ssh/
   chmod 400 ~/.ssh/instance_key.pem
   ```

   Update `ansible/ansible.cfg`:
   ```ini
   private_key_file = ~/.ssh/instance_key.pem
   ```

   Key pair name in `terraform.tfvars`:
   ```hcl
   key_name = "instance_key"
   ```

6. **Ansible**: On deployment machine (RHEL/CentOS VM)
   ```bash
   sudo yum install -y python3 python3-pip
   pip3 install ansible
   ```

7. **jq**: JSON query tool
   ```bash
   sudo yum install -y jq
   ```

## Usage

### Step 1: Clone and Navigate
```bash
git clone https://github.com/amitkoundal02/aws-webapp-infra.git
cd aws-webapp-infra/terraform/
```

### Step 2: Configure Terraform Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
# - Set admin_cidr_blocks to your IP: curl ifconfig.me
# - Update alert_email to receive RDS alerts
```

### Step 3: Set Database Password
```bash
export TF_VAR_db_password="YourSecurePassword123!"
```

### Step 4: Initialize Terraform
```bash
terraform init
```

### Step 5: Plan the Infrastructure
```bash
terraform plan
```

### Step 6: Apply Infrastructure (10-15 min for RDS)
```bash
terraform apply
```

### Step 7: Note the Outputs
```bash
terraform output
# Outputs you will see:
# alb_dns_name      = use this for curl and browser testing
# monitor_public_ip = use this for Grafana SSH tunnel
# rds_endpoint      = RDS connection string
# lambda_function_name = Lambda monitor function name
```

### Step 8: Confirm SNS Subscription
Check your email and confirm the SNS subscription from AWS.

### Step 9: Copy Ansible Folder to RHEL VM
```bash
scp -r ../ansible/ YOUR_USERNAME@RHEL_VM_IP:~/
ssh YOUR_USERNAME@RHEL_VM_IP
cd ansible/
```

### Step 10: Populate Inventory
```bash
cd ansible/
bash update_ips.sh
cat inventory.ini  # Verify IPs are present
```

### Step 11: Test Ansible Connectivity
```bash
ansible all -i inventory.ini -m ping
```

### Step 12: Run Ansible Playbook
```bash
ansible-playbook -i inventory.ini site.yml
# Installs Apache, Node Exporter, Prometheus, Grafana
```

### Step 13: Verify Web Application
```bash
curl http://<ALB_DNS_NAME>/health
# Should return: OK (200 status)
```

### Step 14: Access Grafana via SSH Tunnel
From your laptop:
```bash
ssh -L 3000:<MONITOR_IP>:3000 -i ~/.ssh/instance_key.pem ec2-user@<MONITOR_IP>
# Then open: http://localhost:3000
# Default: admin / admin
```

### Step 15: Cleanup (Destroy Resources)
```bash
cd terraform/
terraform destroy
# Confirms before destroying — DO NOT skip this in production!
```

## Security Design

- **ALB**: Only port 80 exposed to internet (0.0.0.0/0)
- **EC2 from ALB**: Port 80 allowed only from ALB security group
- **EC2 SSH**: Port 22 allowed only from `admin_cidr_blocks` (your IP)
- **RDS**: Port 3306 allowed only from EC2 security group (no public access)
- **IAM Roles**: EC2 instances assume roles with minimum required permissions
  - Lambda IAM role scoped to cloudwatch:GetMetricStatistics and sns:Publish on the specific topic ARN only
  - CloudWatch Logs for Lambda execution
  - No hardcoded AWS keys on instances
- **Secrets Management**: Database password passed via `TF_VAR_db_password` environment variable (never in code)
- **Terraform State**: Encrypted at rest in S3, locked via DynamoDB
- **Resource Tagging**: All resources tagged for cost allocation and compliance audits

## Lab vs Production Tradeoffs

| Component | This Lab | Production |
|-----------|----------|------------|
| Load Balancer | ALB port 80 only | ALB + HTTPS with ACM certificate + WAF |
| Database | Single-AZ, no backup redundancy | Multi-AZ RDS with automated snapshots + point-in-time recovery |
| Network | No NAT Gateway (public EC2) | NAT Gateway for private EC2 egress + VPC endpoints |
| Secrets | TF_VAR environment variable | AWS Secrets Manager + rotation policies |
| EC2 Size | t2.micro (1 vCPU, 1GB) | t3.small+ right-sized per load testing |
| Monitoring | Self-hosted Prometheus/Grafana | CloudWatch + Datadog/New Relic + AlertManager |
| Auto Scaling | Min 1 Max 2 at 70% CPU | Min 2 Max 10+ with target tracking policies |
| Disaster Recovery | No multi-region | Active-active or active-passive across regions |

## Cost Estimate

### Free Tier (First 12 Months)
- **EC2 t2.micro**: 750 hours/month = FREE
- **RDS db.t3.micro**: 750 hours/month = FREE
- **ALB**: First month free, then ~$16/month
- **Data Transfer**: 100GB/month free
- **Total**: ~$0/month (or ~$16 if ALB exceeds free tier)

### After Free Tier Expires
- **RDS db.t3.micro**: ~$12/month
- **ALB**: ~$16/month (0.006 per hour, ~730 hours/month)
- **EC2 t2.micro**: ~$8/month (0.011 per hour, two instances)
- **Data Transfer**: ~$0 (minimal inter-AZ)
- **Estimated Total**: **~$25-35/month**

⚠️ **Always run `terraform destroy` after testing to avoid unexpected charges!**

## Built with GitHub Copilot

This project was built using **GitHub Copilot** for AI-assisted Terraform and Ansible code generation. All generated code was manually reviewed, tested with `terraform plan`, and corrected where needed. Copilot accelerated development while human review ensured correctness and security.

## Author

**Amit Koundal**
- GitHub: [github.com/amitkoundal02](https://github.com/amitkoundal02)
- LinkedIn: [linkedin.com/in/amit-koundal-5833ba33a](https://linkedin.com/in/amit-koundal-5833ba33a)
- Certification: AWS Certified Solutions Architect - Associate
