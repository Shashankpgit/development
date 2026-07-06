# EC2 — 06: EC2 in Practice

> **Last updated:** July 5, 2026
> **Launch a real server, install Nginx, create a custom AMI — full hands-on walkthrough.**

---

## Hands-On: Launch an EC2 Instance via Console

### Step 1: Go to EC2 → Launch Instance

**Name:** `vault-web-01`

**Application and OS Images (AMI):**
- Quick Start → Amazon Linux 2023 AMI
- Architecture: x86_64

**Instance type:** `t3.micro` (free tier eligible)

**Key pair:** Create new → Name: `vault-key` → RSA → .pem → Download it

**Network settings:**
- VPC: your custom VPC (or default for testing)
- Subnet: Public subnet
- Auto-assign public IP: Enable
- Security Group: Create new → name it `vault-web-sg`
  - Add inbound rule: HTTP, port 80, source `0.0.0.0/0`
  - Add inbound rule: SSH, port 22, source `My IP`

**Configure storage:**
- 1x 8GB gp3 (root volume) — that's the default, fine for now

**Advanced Details → IAM instance profile:** None for now

Click **Launch Instance**.

---

## Step 2: Connect to Your Instance

```bash
# Fix key permissions (required by SSH)
chmod 400 vault-key.pem

# Connect (replace PUBLIC_IP with your instance's public IP)
ssh -i vault-key.pem ec2-user@PUBLIC_IP

# You should see the Amazon Linux prompt:
# [ec2-user@ip-10-0-1-50 ~]$
```

---

## Step 3: Install and Configure Nginx

```bash
# Once connected to EC2:

# Update packages
sudo dnf update -y    # Amazon Linux 2023 uses dnf

# Install Nginx
sudo dnf install nginx -y

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify it's running
sudo systemctl status nginx

# Test locally
curl http://localhost
# Should return the Nginx welcome HTML
```

Now open your browser and go to `http://YOUR_EC2_PUBLIC_IP`. You should see the Nginx welcome page.

---

## Step 4: Create a Simple App Page

```bash
# Create a custom index page
sudo tee /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Vault App</title></head>
<body>
  <h1>Vault App is running!</h1>
  <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
  <p>AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
</body>
</html>
EOF

# Reload Nginx
sudo systemctl reload nginx
```

Refresh your browser — you see the custom page.

---

## Step 5: Add a Data Volume

```bash
# From your local machine:

# Create a 20GB gp3 EBS volume in the same AZ as your EC2
aws ec2 create-volume \
  --size 20 \
  --volume-type gp3 \
  --availability-zone ap-south-1a \
  --tag-specifications '[{"ResourceType":"volume","Tags":[{"Key":"Name","Value":"vault-data"}]}]'

# Note the VolumeId from output: vol-0123456789abcdef0

# Attach it to your instance
aws ec2 attach-volume \
  --volume-id vol-0123456789abcdef0 \
  --instance-id i-1234567890abcdef0 \
  --device /dev/xvdf
```

```bash
# Back on the EC2 instance:

# Check if the volume is attached
lsblk
# You should see: xvdf  202:80  0  20G  0 disk

# Format the volume (only do this once — destroys existing data)
sudo mkfs.ext4 /dev/xvdf

# Create a mount point
sudo mkdir -p /data

# Mount it
sudo mount /dev/xvdf /data

# Verify
df -h /data
# /dev/xvdf  20G  44M  19G  1% /data

# Make it mount automatically on reboot
echo '/dev/xvdf /data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

---

## Step 6: Create a Custom AMI

Now that you have Nginx installed, create an AMI so you can launch more instances like this:

```bash
# From your local machine:

# Create the AMI (doesn't reboot by default with --no-reboot)
aws ec2 create-image \
  --instance-id i-1234567890abcdef0 \
  --name "nginx-base-$(date +%Y%m%d)" \
  --description "Amazon Linux 2023 with Nginx" \
  --no-reboot

# Wait for it to be ready
aws ec2 wait image-available --image-ids ami-0123456789abcdef0

# Verify
aws ec2 describe-images \
  --owners self \
  --query 'Images[*].{Name:Name,ID:ImageId,State:State}'
```

Now you can launch new instances from this AMI — they'll already have Nginx installed.

---

## Step 7: Launch from Your Custom AMI + User Data

Now launch a new instance from your AMI with a User Data script that customizes it:

```bash
cat > userdata.sh << 'EOF'
#!/bin/bash
# This runs at first boot — Nginx is already installed from the AMI
# This script just customizes the content

# Get the instance ID from metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Create a custom index page
cat > /usr/share/nginx/html/index.html << HTMLEOF
<!DOCTYPE html>
<html>
<body>
  <h1>Vault App</h1>
  <p>Instance: $INSTANCE_ID</p>
  <p>Zone: $AZ</p>
</body>
</html>
HTMLEOF

systemctl start nginx
EOF

aws ec2 run-instances \
  --image-id ami-YOUR-CUSTOM-AMI-ID \
  --instance-type t3.micro \
  --key-name vault-key \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-public-az-a \
  --user-data file://userdata.sh \
  --tag-specifications '[{"ResourceType":"instance","Tags":[{"Key":"Name","Value":"vault-web-02"}]}]'
```

---

## Common Instance Management Commands

```bash
# ── LIST ──────────────────────────────────────────────────────
# List all instances
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{
    Name:Tags[?Key==`Name`]|[0].Value,
    ID:InstanceId,
    Type:InstanceType,
    State:State.Name,
    IP:PublicIpAddress,
    PrivateIP:PrivateIpAddress
  }' \
  --output table

# ── START / STOP / REBOOT / TERMINATE ─────────────────────────
aws ec2 stop-instances --instance-ids i-xxxx
aws ec2 start-instances --instance-ids i-xxxx
aws ec2 reboot-instances --instance-ids i-xxxx
aws ec2 terminate-instances --instance-ids i-xxxx   # permanent!

# Wait for state
aws ec2 wait instance-running  --instance-ids i-xxxx
aws ec2 wait instance-stopped  --instance-ids i-xxxx

# ── GET PUBLIC IP ─────────────────────────────────────────────
aws ec2 describe-instances \
  --instance-ids i-xxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text

# ── VIEW CONSOLE OUTPUT (boot logs) ───────────────────────────
aws ec2 get-console-output --instance-ids i-xxxx --output text

# ── CHECK INSTANCE STATUS ─────────────────────────────────────
aws ec2 describe-instance-status --instance-ids i-xxxx
```

---

## Troubleshooting Checklist

### Can't SSH into EC2

```
□ Is the instance in RUNNING state?
□ Does the instance have a Public IP?
□ Is the subnet's route table pointing 0.0.0.0/0 to IGW?
□ Does the Security Group allow TCP 22 from your IP?
□ Are you using the right username? (ec2-user, ubuntu, admin)
□ Did you chmod 400 the .pem file?
□ Are you using the right .pem file (matches the key pair the instance was launched with)?
□ Is it timing out (network) or refusing (auth)? Timeout = SG/routing. Refused = app issue.
```

### Website not loading

```
□ Is Nginx/your app actually running? (sudo systemctl status nginx)
□ Is port 80 in the Security Group inbound rules?
□ Are you using HTTP (not HTTPS) if no SSL configured?
□ Check app logs: sudo journalctl -u nginx -f
```

### Instance keeps restarting

```
□ Check system logs: aws ec2 get-console-output --instance-ids i-xxxx
□ Check CloudWatch metrics: CPU? Memory? Disk?
□ May be a User Data script error — check /var/log/cloud-init-output.log
```

---

## Clean Up (Avoid Unexpected Charges)

```bash
# Terminate EC2 instances
aws ec2 terminate-instances --instance-ids i-xxxx

# Delete EBS volumes (volumes NOT attached to terminated instances)
aws ec2 delete-volume --volume-id vol-xxxx

# Release Elastic IPs (charged if not attached)
aws ec2 release-address --allocation-id eipalloc-xxxx

# Deregister custom AMIs
aws ec2 deregister-image --image-id ami-xxxx

# Delete associated snapshots
aws ec2 delete-snapshot --snapshot-id snap-xxxx

# Delete NAT Gateway (charged hourly even if no traffic)
aws ec2 delete-nat-gateway --nat-gateway-id nat-xxxx

# Delete VPC (only after all resources inside are deleted)
aws ec2 delete-vpc --vpc-id vpc-xxxx
```

→ You've completed the EC2 section. Phase 1 is complete.

**Next:** Phase 2 — Storage Layer: `aws/phase2/s3/`
