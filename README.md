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
         ## Usage — End to End Setup

         ### Phase 1: Prerequisites (One-time setup)

         Step 1: Clone the repository
         ```bash
         git clone https://github.com/amitkoundal02/aws-webapp-infra.git
         cd aws-webapp-infra/terraform/
         ```

         Step 2: Create S3 bucket for Terraform state
         ```bash
         aws s3api create-bucket \
            --bucket aws-webapp-infra-remote-state \
            --region ap-south-1 \
            --create-bucket-configuration LocationConstraint=ap-south-1
         aws s3api put-bucket-versioning \
            --bucket aws-webapp-infra-remote-state \
            --versioning-configuration Status=Enabled
         ```

         Step 3: Create DynamoDB table for state locking
         ```bash
         aws dynamodb create-table \
            --table-name aws-webapp-infra-state-lock \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region ap-south-1
         ```

         Step 4: Convert SSH key from PPK to PEM (Windows)
         - Open PuTTYgen
         - Load instance_key.ppk
         - Conversions → Export OpenSSH key
         - Save as instance_key.pem
         - Copy to RHEL VM: 
            ```bash
            scp instance_key.pem YOUR_USERNAME@RHEL_VM_IP:~/.ssh/
            chmod 400 ~/.ssh/instance_key.pem
            ```

         Step 5: Configure terraform.tfvars
         ```bash
         cp terraform.tfvars.example terraform.tfvars
         ```
         Edit terraform.tfvars and set:
         - admin_cidr_blocks with your laptop IP AND 
            RHEL VM IP (get each with: curl ifconfig.me)
         - alert_email with your real email
         - key_name = "instance_key"

         Step 6: Set database password (never in files)
         ```bash
         export TF_VAR_db_password="YourSecurePassword"
         ```

         ### Phase 2: Deploy Infrastructure with Terraform

         Step 7: Initialize Terraform
         ```bash
         cd terraform/
         terraform init
         ```

         Step 8: Preview what will be created
         ```bash
         terraform plan
         ```
         (Review 33 resources before applying)

         Step 9: Apply infrastructure (takes 10-15 minutes)
         ```bash
         terraform apply
         ```
         Type "yes" when prompted

         Step 10: Save the outputs
         ```bash
         terraform output
         ```
         Save these values:
         - alb_dns_name      → web app URL
         - monitor_public_ip → Grafana/Prometheus server IP
         - rds_endpoint      → database connection string

         Step 11: Confirm SNS email subscription
         Check your email inbox for AWS notification email
         Click "Confirm subscription" link
         (Without this Lambda alerts will not be delivered)

         ### Phase 3: Configure Infrastructure with Ansible

         Step 12: On your RHEL VM, install prerequisites
         ```bash
         pip3 install ansible
         sudo dnf install -y jq
         aws configure  (use same credentials as laptop)
         ```

         Step 13: Copy Ansible code to RHEL VM (from laptop)
         ```bash
         scp -r ansible/ YOUR_USERNAME@RHEL_VM_IP:~/
         ```

         Step 14: SSH into RHEL VM and run update_ips.sh
         ```bash
         ssh YOUR_USERNAME@RHEL_VM_IP
         cd ansible/
         chmod +x update_ips.sh
         ./update_ips.sh
         cat inventory.ini
         ```
         (Verify web and monitor IPs appear — not empty)

         Step 15: Test SSH connectivity to EC2 instances
         ```bash
         ansible all -i inventory.ini -m ping
         ```
         (All instances should return pong)
         If UNREACHABLE — check admin_cidr_blocks includes 
         RHEL VM IP and re-run terraform apply

         Step 16: Run Ansible playbook
         ```bash
         ansible-playbook -i inventory.ini site.yml
         ```
         (Takes 5-10 minutes)
         Installs on web hosts: Apache, node_exporter
         Installs on monitor host: Prometheus, Grafana, node_exporter

         ### Phase 4: Verify Everything Works

         Step 17: Test web application via ALB
         ```bash
         curl http://ALB_DNS_NAME/
         curl http://ALB_DNS_NAME/health
         ```
         (Both should return HTTP 200)
         Open ALB_DNS_NAME in browser to see the web page

         Step 18: Access Grafana dashboard
         From your laptop run:
         ```bash
         ssh -L 3000:MONITOR_PUBLIC_IP:3000 \
            -i ~/.ssh/instance_key.pem \
            ec2-user@MONITOR_PUBLIC_IP
         ```
         Then open: http://localhost:3000
         Login: admin / admin (change password immediately)

         Step 19: Access Prometheus targets
         From your laptop run:
         ```bash
         ssh -L 9090:MONITOR_PUBLIC_IP:9090 \
            -i ~/.ssh/instance_key.pem \
            ec2-user@MONITOR_PUBLIC_IP
         ```
         Then open: http://localhost:9090/targets
         All targets should show State = UP

         Step 20: Verify Lambda monitoring
         In AWS Console → Lambda → aws-webapp-infra-rds-monitor
         Click Test → create test event → run
         Check CloudWatch Logs for execution output
         SNS email arrives if RDS storage below 5GB

         Step 21: Verify Auto Scaling (optional test)
         ```bash
         aws autoscaling describe-auto-scaling-groups \
            --region ap-south-1 \
            --query 'AutoScalingGroups[].{Name:AutoScalingGroupName,Min:MinSize,Max:MaxSize,Desired:DesiredCapacity}'
         ```

         ### Phase 5: Cleanup

         Step 22: Destroy all infrastructure when done
         ```bash
         cd terraform/
         terraform destroy
         ```
         Type "yes" when prompted
         (Removes all resources except S3 bucket and 
         DynamoDB table which are needed for future runs)

         Step 23: Verify no resources running
         ```bash
         aws resourcegroupstaggingapi get-resources \
            --tag-filters Key=Project,Values=aws-webapp-infra \
            --region ap-south-1 \
            --query 'ResourceTagMappingList[].ResourceARN'
         ```
         (Should return empty list [])
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
