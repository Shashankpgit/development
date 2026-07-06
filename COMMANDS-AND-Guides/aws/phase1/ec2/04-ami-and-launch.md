# EC2 — 04: AMIs and Launching Instances

> **Last updated:** July 5, 2026
> **What an AMI is, how User Data works, key pairs, and launching instances correctly.**

---

## What Is an AMI?

An **AMI (Amazon Machine Image)** is a template that contains:
- The operating system (Amazon Linux, Ubuntu, Windows Server, etc.)
- Pre-installed software (optionally)
- Configuration (optionally)
- EBS snapshot(s) defining the root volume

When you launch an EC2 instance, you choose an AMI. AWS uses the AMI to create your instance — it's like a mold.

```
AMI → Launch → EC2 Instance
               (running copy of the AMI)

You can launch the same AMI 1 time or 1,000 times
Each launch creates an independent instance
```

---

## AMI Types

### AWS-Provided AMIs (in the AWS Marketplace / Public AMIs)

```
Amazon Linux 2023     → AWS's own Linux distribution, optimized for EC2
                         Most common for new projects
                         Includes AWS CLI, SSM agent pre-installed

Amazon Linux 2        → Older AWS Linux, still widely used

Ubuntu 22.04 LTS      → Popular for developers familiar with Ubuntu
Ubuntu 24.04 LTS      → Latest Ubuntu LTS

Windows Server 2022   → For .NET and Windows workloads

Red Hat Enterprise    → RHEL (paid subscription required)
SUSE Linux            → SUSE Linux (paid subscription required)
```

### AWS Marketplace AMIs

Pre-configured AMIs sold by third parties — Nginx Plus, Palo Alto firewall, etc. They often have additional software license costs.

### Community AMIs

Public AMIs shared by other AWS users. Use with caution — review source and content.

### Your Own Custom AMIs

**You create an AMI from a running EC2 instance.** This captures the exact state of the disk (OS + all software you installed) as an AMI you can relaunch.

---

## Creating a Custom AMI

Use case: You've installed and configured your application on an EC2. Now you want to launch more instances exactly like it (for an Auto Scaling Group).

```bash
# Step 1: Configure your EC2 instance (install app, configure)
# Step 2: Create AMI from the running instance
aws ec2 create-image \
  --instance-id i-1234567890abcdef0 \
  --name "vault-api-v1.2.3-$(date +%Y%m%d)" \
  --description "Vault API with Node.js 20 and dependencies" \
  --no-reboot

# --no-reboot: don't reboot the instance (may result in a slightly inconsistent snapshot)
# Omit --no-reboot to let AWS reboot for a clean snapshot (instance will be unavailable briefly)

# The AMI is created — this takes a few minutes
# Status: pending → available

aws ec2 describe-images --owners self --query 'Images[*].{Name:Name,ID:ImageId,State:State}'
```

**What gets captured:**
- Everything on the root EBS volume (OS, installed packages, app files, configs)
- NOT: RAM contents, running processes, external volumes (unless you include them)

**What to do BEFORE creating the AMI:**
```bash
# Clear sensitive data (temp credentials, test data)
# Clear logs
sudo rm -rf /var/log/*
# Clear bash history
history -c
# Optionally run cloud-init cleanup (for Amazon Linux)
sudo cloud-init clean
```

---

## AMI Lifecycle Management

```bash
# List your AMIs
aws ec2 describe-images --owners self

# Copy AMI to another region (for DR)
aws ec2 copy-image \
  --source-image-id ami-0123456789abcdef0 \
  --source-region ap-south-1 \
  --region us-east-1 \
  --name "vault-api-v1.2.3-us-east-1"

# Share AMI with another account
aws ec2 modify-image-attribute \
  --image-id ami-0123456789abcdef0 \
  --launch-permission "Add=[{UserId=999999999999}]"

# Deregister (delete) an AMI you no longer need
aws ec2 deregister-image --image-id ami-0123456789abcdef0
# Note: Deregistering the AMI doesn't delete the snapshot — do that separately
aws ec2 delete-snapshot --snapshot-id snap-0123456789abcdef0
```

---

## User Data — Bootstrap Scripts

**User Data** is a script that runs automatically when an EC2 instance launches for the **first time**. It runs as root. Used to install software, configure the environment, download your app.

### Writing User Data

```bash
#!/bin/bash
# This is a User Data script for Amazon Linux 2023

# Update system packages
yum update -y

# Install Node.js 20
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# Install nginx
yum install -y nginx
systemctl enable nginx
systemctl start nginx

# Download app from S3 (EC2 needs IAM role with S3 read permission)
aws s3 cp s3://vault-app-deploy/latest.tar.gz /home/ec2-user/
cd /home/ec2-user && tar -xzf latest.tar.gz

# Install dependencies
cd /home/ec2-user/vault-api
npm install --production

# Create systemd service
cat > /etc/systemd/system/vault-api.service << 'EOF'
[Unit]
Description=Vault API
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/vault-api
ExecStart=/usr/bin/node src/server.js
Restart=on-failure
Environment=NODE_ENV=production
Environment=PORT=8080

[Install]
WantedBy=multi-user.target
EOF

systemctl enable vault-api
systemctl start vault-api

# Log completion
echo "User data script completed at $(date)" >> /var/log/user-data.log
```

### Passing User Data (CLI)

```bash
aws ec2 run-instances \
  --image-id ami-0123456789abcdef0 \
  --instance-type t3.medium \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-0123456789abcdef0 \
  --iam-instance-profile Name=vault-api-role \
  --user-data file://userdata.sh
```

### Debugging User Data

```bash
# SSH into the instance, check if the script ran
cat /var/log/cloud-init-output.log   # Amazon Linux / Ubuntu
cat /var/log/user-data.log           # if you wrote to this file

# Check cloud-init status
cloud-init status
```

### User Data Runs Only Once

By default, User Data runs only on the **first launch** of an instance. If you stop and start the instance, it does NOT run again.

To force it to run again on every boot (unusual need):
```bash
# In user data, configure cloud-init to run it every boot:
# /var/lib/cloud/instances/<instance-id>/scripts/ — run-once vs run-always
```

---

## Key Pairs — SSH Access

A **key pair** is an SSH authentication mechanism. You use the private key to log into EC2.

**How it works:**
```
You generate a key pair:
  Private key: vault-key.pem   (you keep this, never share it)
  Public key:  vault-key-pub   (AWS stores this on the instance)

When you SSH:
  Your SSH client uses the private key to authenticate
  EC2 verifies it against the stored public key
  If they match → access granted
```

**Creating a key pair:**

```bash
# Create a key pair and save the private key
aws ec2 create-key-pair \
  --key-name vault-key \
  --query 'KeyMaterial' \
  --output text > vault-key.pem

# Fix permissions (SSH refuses keys that are world-readable)
chmod 400 vault-key.pem

# List key pairs
aws ec2 describe-key-pairs

# Delete a key pair (only deletes from AWS — doesn't affect your local .pem file)
aws ec2 delete-key-pair --key-name vault-key
```

**SSH into EC2:**

```bash
# Amazon Linux / RHEL
ssh -i vault-key.pem ec2-user@PUBLIC_IP

# Ubuntu
ssh -i vault-key.pem ubuntu@PUBLIC_IP

# Windows (user is Administrator or ec2-user depending on AMI)
ssh -i vault-key.pem administrator@PUBLIC_IP
```

**What if you lose the private key?**

You can't recover it from AWS. Options:
1. Stop the instance, detach root EBS volume, attach to another EC2, mount it, add a new public key to `~/.ssh/authorized_keys`
2. Use AWS Systems Manager Session Manager (doesn't require SSH keys)

---

## Launching an Instance (Full CLI Example)

```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \      # Amazon Linux 2023 in ap-south-1
  --instance-type t3.medium \
  --count 1 \
  --key-name vault-key \
  --security-group-ids sg-0123456789 \
  --subnet-id subnet-public-az-a \
  --iam-instance-profile Name=vault-api-role \
  --block-device-mappings '[{
    "DeviceName": "/dev/xvda",
    "Ebs": {
      "VolumeSize": 30,
      "VolumeType": "gp3",
      "DeleteOnTermination": true,
      "Encrypted": true
    }
  }]' \
  --user-data file://userdata.sh \
  --tag-specifications '[{
    "ResourceType": "instance",
    "Tags": [{"Key": "Name", "Value": "vault-api-prod-1"}]
  }]' \
  --metadata-options HttpTokens=required   # Enforce IMDSv2 (more secure)
```

→ Continue to: `05-networking.md`
