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
                          INTERNET
                              |
                         ┌────▼────┐
                         │   ALB   │  Port 80 — internet-facing
                         └────┬────┘
                    ┌─────────┴──────────┐
           ┌────────▼────────┐  ┌────────▼────────┐
           │  Public SN AZ-a │  │  Public SN AZ-b │
           │  EC2 t2.micro   │  │  EC2 t2.micro   │
           │  Apache :80     │  │  Apache :80     │
           │  node_exp :9100 │  │  node_exp :9100 │
           └────────┬────────┘  └────────┬────────┘
                    │  Auto Scaling Group  │
                    │   min:1  max:2       │
                    └──────────┬───────────┘
                               │ MySQL :3306
               ┌───────────────▼───────────────┐
               │   Private Subnets (AZ-a/AZ-b) │
               │   RDS MySQL 8.0 db.t3.micro   │
               │   Single-AZ  20GB  No public  │
               └───────────────────────────────┘

  ┌──────────────────────────────────────────────┐
  │  Public Subnet — Monitor EC2 t2.micro        │
  │  Prometheus :9090  Grafana :3000             │
  │  node_exporter :9100                         │
  │  Scrapes all instances on port 9100          │
  └──────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────┐
  │  EventBridge (every 5 min)                   │
  │    → Lambda Python 3.12 (rds_monitor.py)     │
  │      → CloudWatch GetMetricStatistics        │
  │        → SNS Email Alert (storage < 5GB)     │
  └──────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────┐
  │  Terraform Remote State                      │
  │  S3: aws-webapp-infra-remote-state           │
  │  DynamoDB: aws-webapp-infra-state-lock       │
  └──────────────────────────────────────────────┘
```

## What This Provisions

- **VPC** `10.0.0.0/16` with 4 subnets across 2 AZs (ap-south-1a, ap-south-1b)
- **Internet Gateway** for public subnets (no NAT Gateway — cost saving for lab)
- **Application Load Balancer** internet-facing, port 80, health check on `/health`
- **Auto Scaling Group** min 1, max 2, t2.micro — scales out at 70% CPU
- **Monitor EC2** t2.micro — dedicated Prometheus + Grafana host
- **RDS MySQL 8.0** db.t3.micro, 20GB gp2, single-AZ, private subnet only
- **Lambda** Python 3.12 — triggered every 5 min, monitors RDS free storage
- **SNS Email Alert** when RDS storage drops below 5GB
- **S3 + DynamoDB** Terraform remote state with locking
- **IAM Instance Profiles** on EC2 — least privilege, no hardcoded credentials
- **Security Groups** layered — ALB → EC2 → RDS, each accepting only from previous tier
- **All resources tagged** `Project`, `Environment`, `ManagedBy`

## Prerequisites

**1. AWS CLI configured**
```bash
aws configure
# Region: ap-south-1
```

**2. Terraform >= 1.5**
```bash
terraform --version
```

**3. Create S3 bucket for Terraform state** *(one-time)*
```bash
aws s3api create-bucket \
  --bucket aws-webapp-infra-remote-state \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning \
  --bucket aws-webapp-infra-remote-state \
  --versioning-configuration Status=Enabled
```

**4. Create DynamoDB table for state locking** *(one-time)*
```bash
aws dynamodb create-table \
  --table-name aws-webapp-infra-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

**5. Convert SSH key from PPK to PEM** *(Windows — one-time)*
- Open **PuTTYgen** → Load `instance_key.ppk`
- Go to **Conversions → Export OpenSSH key** → Save as `instance_key.pem`
- Copy to RHEL VM:
```bash
scp instance_key.pem YOUR_USERNAME@RHEL_VM_IP:~/.ssh/
# On RHEL VM:
chmod 400 ~/.ssh/instance_key.pem
```

**6. Ansible on RHEL VM**
```bash
pip3 install ansible
sudo dnf install -y jq
aws configure   # same credentials as laptop
```

---

## Usage — End to End

### Phase 1: Deploy Infrastructure with Terraform

**Step 1: Clone and navigate**
```bash
git clone https://github.com/amitkoundal02/aws-webapp-infra.git
cd aws-webapp-infra/terraform/
```

**Step 2: Configure variables**
```bash
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` and set:
- `admin_cidr_blocks` — your laptop IP **and** RHEL VM IP (run `curl ifconfig.me` on each)
- `alert_email` — your real email address for SNS alerts
- `key_name = "instance_key"` — your existing key pair in ap-south-1

**Step 3: Set database password** *(never store in files)*
```bash
export TF_VAR_db_password="YourSecurePassword"
```

**Step 4: Initialize and deploy**
```bash
terraform init
terraform plan        # review 33 resources before applying
terraform apply       # takes 10-15 minutes (RDS provisioning)
```

**Step 5: Save outputs**
```bash
terraform output
```
Note these values:
- `alb_dns_name` → web app URL for testing
- `monitor_public_ip` → Grafana/Prometheus server IP
- `rds_endpoint` → database connection string
- `lambda_function_name` → Lambda monitor function name

**Step 6: Confirm SNS email subscription**
Check your inbox for AWS notification email → click **Confirm subscription**
*(Without this, Lambda RDS alerts will not be delivered)*

---

### Phase 2: Configure Instances with Ansible

**Step 7: Copy Ansible to RHEL VM** *(from laptop)*
```bash
scp -r ansible/ YOUR_USERNAME@RHEL_VM_IP:~/
ssh YOUR_USERNAME@RHEL_VM_IP
cd ansible/
```

**Step 8: Populate inventory from AWS**
```bash
chmod +x update_ips.sh
./update_ips.sh
cat inventory.ini    # verify web and monitor IPs appear — not empty
```
Expected output:
```
[web]
13.233.xxx.xxx

[monitor]
15.207.xxx.xxx
```
If empty — check `admin_cidr_blocks` includes RHEL VM IP and re-run `terraform apply`

**Step 9: Test connectivity**
```bash
ansible all -i inventory.ini -m ping
```
All instances should return `pong`. If `UNREACHABLE` — verify port 22 is open from your RHEL VM IP.

**Step 10: Run Ansible playbook**
```bash
ansible-playbook -i inventory.ini site.yml
```
Takes 5-10 minutes. Installs:
- Web hosts: Apache httpd, node_exporter
- Monitor host: Prometheus, Grafana, node_exporter

---

### Phase 3: Verify Everything Works

**Step 11: Test web application**
```bash
curl http://ALB_DNS_NAME/health    # should return: OK
curl http://ALB_DNS_NAME/          # should return HTML page
```
Or open `http://ALB_DNS_NAME` in browser.

**Step 12: Access Grafana** *(via SSH tunnel from laptop)*
```bash
ssh -L 3000:MONITOR_PUBLIC_IP:3000 \
  -i ~/.ssh/instance_key.pem \
  ec2-user@MONITOR_PUBLIC_IP
```
Open `http://localhost:3000` → Login: `admin` / `admin` *(change password immediately)*

**Step 13: Access Prometheus targets** *(via SSH tunnel from laptop)*
```bash
ssh -L 9090:MONITOR_PUBLIC_IP:9090 \
  -i ~/.ssh/instance_key.pem \
  ec2-user@MONITOR_PUBLIC_IP
```
Open `http://localhost:9090/targets` → all targets should show **State = UP**

**Step 14: Verify Lambda monitoring**
- AWS Console → Lambda → `aws-webapp-infra-rds-monitor`
- Click **Test** → create empty test event → **Invoke**
- Check CloudWatch Logs for execution output
- SNS email arrives if RDS storage is below 5GB

**Step 15: Verify Auto Scaling**
```bash
aws autoscaling describe-auto-scaling-groups \
  --region ap-south-1 \
  --query 'AutoScalingGroups[].{Name:AutoScalingGroupName,Min:MinSize,Max:MaxSize,Desired:DesiredCapacity}'
```

---

### Phase 4: Cleanup

**Step 16: Destroy all infrastructure**
```bash
cd terraform/
terraform destroy
```
Type `yes` when prompted. Removes all resources except S3 bucket and DynamoDB table.

**Step 17: Verify no resources running**
```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=aws-webapp-infra \
  --region ap-south-1 \
  --query 'ResourceTagMappingList[].ResourceARN'
```
Should return `[]` — empty list confirms no chargeable resources running.

---

## Security Design

| Layer | Rule |
|---|---|
| ALB | Port 80 open to internet `0.0.0.0/0` only |
| EC2 port 80 | Accepts only from ALB security group (not internet directly) |
| EC2 port 22 | Accepts only from `admin_cidr_blocks` (your IPs) |
| EC2 port 9100 | Accepts only from `admin_cidr_blocks` (Prometheus scraping) |
| RDS port 3306 | Accepts only from ASG security group (no public access) |
| IAM | EC2 instance profiles with least-privilege policies — no hardcoded AWS keys |
| Secrets | `db_password` via `TF_VAR_` environment variable — never in code or files |
| State | Terraform state encrypted at rest in S3, locked via DynamoDB |

## Lab vs Production Tradeoffs

| Component | This Lab | Production |
|---|---|---|
| Load Balancer | HTTP port 80 only | HTTPS with ACM certificate + WAF |
| Database | Single-AZ, no backups | Multi-AZ + automated snapshots |
| Network | No NAT Gateway (public EC2) | NAT Gateway for private egress |
| Secrets | TF_VAR environment variable | AWS Secrets Manager + rotation |
| EC2 Size | t2.micro | Right-sized per load testing |
| Monitoring | Self-hosted Prometheus/Grafana | Datadog / CloudWatch / New Relic |
| Auto Scaling | Min 1 Max 2 at 70% CPU | Min 2 Max 10+ with target tracking |
| Disaster Recovery | Single region | Active-active or active-passive multi-region |

## Cost Estimate

### Free Tier (first 12 months)
- EC2 t2.micro: 750 hrs/month = **FREE**
- RDS db.t3.micro: 750 hrs/month = **FREE**
- ALB: ~**$16/month** (not fully free after first month)
- Lambda + EventBridge: **FREE** (well within 1M free invocations)

### After Free Tier
- RDS: ~$12/month · ALB: ~$16/month · EC2 (x2): ~$8/month
- **Estimated total: ~$25-35/month**

⚠️ **Always run `terraform destroy` after testing to avoid unexpected charges.**

## Built with GitHub Copilot

This project was built using **GitHub Copilot** for AI-assisted Terraform and Ansible code generation. All generated code was manually reviewed, tested with `terraform plan`, and corrected where needed. Copilot accelerated development while human review ensured correctness and security.

## Author

**Amit Koundal**
- GitHub: [github.com/amitkoundal02](https://github.com/amitkoundal02)
- LinkedIn: [linkedin.com/in/amit-koundal-5833ba33a](https://linkedin.com/in/amit-koundal-5833ba33a)
- Certification: AWS Certified Solutions Architect – Associate
