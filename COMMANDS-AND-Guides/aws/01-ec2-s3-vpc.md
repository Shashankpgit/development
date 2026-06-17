# AWS — Part 01: EC2, S3, and VPC

---

## EC2 — Elastic Compute Cloud

EC2 is virtual machines in AWS. You pick a machine type, OS, storage, and networking — AWS runs the hardware.

### Key Concepts

**Instance type**: defines CPU + memory. Format: `family`size. Example: `t3.medium` = T3 family (burstable), medium size (2 vCPU, 4GB RAM).

Common families:
- `t3`, `t4g`: burstable, cheapest, dev/test
- `m5`, `m6i`: general purpose, balanced CPU/memory
- `c5`, `c6i`: compute-optimized, CPU-heavy workloads
- `r5`, `r6i`: memory-optimized, databases, caches
- `g4dn`, `p3`: GPU instances

**AMI (Amazon Machine Image)**: the operating system image. Like a Docker image for VMs — it contains the OS + pre-installed software.

**Key pair**: SSH public/private key pair. The public key is stored on the instance; you need the private key (`.pem` file) to SSH in.

**Security Group**: a stateful firewall for instances. Defines which ports are open to which IPs.

**Elastic IP**: a static public IP you can attach to an instance. Normal public IPs change when you stop/start an instance.

### EC2 CLI Commands

```bash
# List running instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].[InstanceId,InstanceType,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]" \
  --output table

# Start/stop instances
aws ec2 start-instances --instance-ids i-1234567890abcdef0
aws ec2 stop-instances --instance-ids i-1234567890abcdef0
aws ec2 reboot-instances --instance-ids i-1234567890abcdef0
aws ec2 terminate-instances --instance-ids i-1234567890abcdef0   # PERMANENT DELETE

# Launch an EC2 instance
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.micro \
  --key-name my-key-pair \
  --security-group-ids sg-12345678 \
  --subnet-id subnet-12345678 \
  --iam-instance-profile Name=EC2S3Access \
  --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=vault-api-server}]' \
  --user-data file://startup-script.sh

# Create a key pair and save the .pem file
aws ec2 create-key-pair \
  --key-name my-key-pair \
  --query "KeyMaterial" \
  --output text > my-key-pair.pem
chmod 400 my-key-pair.pem    # required! SSH refuses keys with open permissions

# SSH into the instance
ssh -i my-key-pair.pem ec2-user@54.123.45.67    # Amazon Linux
ssh -i my-key-pair.pem ubuntu@54.123.45.67      # Ubuntu
```

### Security Groups

```bash
# Create a security group
aws ec2 create-security-group \
  --group-name vault-api-sg \
  --description "Security group for vault-api" \
  --vpc-id vpc-12345678

# Allow SSH from your IP only
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 22 \
  --cidr $(curl -s ifconfig.me)/32

# Allow HTTP and HTTPS from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# List rules
aws ec2 describe-security-groups --group-ids sg-12345678
```

---

## S3 — Simple Storage Service

S3 stores objects (files) in buckets. It's infinitely scalable, highly durable (99.999999999% — 11 nines), and cheap. Used for: static files, backups, Terraform state, Docker image layers, data lakes, log archives.

### S3 Concepts

**Bucket**: a globally-unique container for objects. Name must be unique across all of AWS worldwide.

**Object**: a file stored in S3. Identified by key (the "path"): `images/profile/user123.jpg`.

**Storage classes**: different price/availability tradeoffs:
- `STANDARD`: default, frequently accessed, most expensive
- `STANDARD_IA`: infrequent access, cheaper but retrieval fee
- `GLACIER`: archive storage, very cheap, retrieval takes hours
- `INTELLIGENT_TIERING`: auto-moves objects between tiers based on access

### S3 CLI Commands

```bash
# Create a bucket
aws s3 mb s3://vault-app-storage-2026 --region ap-south-1

# List buckets
aws s3 ls

# List objects in a bucket
aws s3 ls s3://vault-app-storage-2026
aws s3 ls s3://vault-app-storage-2026/uploads/   # list a "folder"

# Upload a file
aws s3 cp myfile.txt s3://vault-app-storage-2026/
aws s3 cp myfile.txt s3://vault-app-storage-2026/backups/2026-06-17.txt

# Upload a directory (recursive)
aws s3 cp ./backups/ s3://vault-app-storage-2026/backups/ --recursive

# Download
aws s3 cp s3://vault-app-storage-2026/backups/2026-06-17.txt ./

# Sync a directory (like rsync — only uploads changes)
aws s3 sync ./dist/ s3://vault-app-storage-2026/frontend/ --delete

# Delete object
aws s3 rm s3://vault-app-storage-2026/old-file.txt

# Delete all objects in prefix
aws s3 rm s3://vault-app-storage-2026/old-backups/ --recursive

# Delete bucket (must be empty first)
aws s3 rb s3://vault-app-storage-2026

# Generate a pre-signed URL (temporary public access to a private object)
aws s3 presign s3://vault-app-storage-2026/private-doc.pdf \
  --expires-in 3600    # valid for 1 hour

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket vault-app-storage-2026 \
  --versioning-configuration Status=Enabled

# Make bucket private (block all public access)
aws s3api put-public-access-block \
  --bucket vault-app-storage-2026 \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### Bucket Policy — Control Access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/EC2S3Access"
      },
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::vault-app-storage-2026/*"
    }
  ]
}
```

```bash
aws s3api put-bucket-policy \
  --bucket vault-app-storage-2026 \
  --policy file://bucket-policy.json
```

---

## VPC — Virtual Private Cloud

A VPC is your private network in AWS. It's an isolated section of the AWS cloud where you launch resources. Every account gets a default VPC in each region.

### VPC Concepts

**CIDR block**: the IP range for your VPC. e.g., `10.0.0.0/16` = 65,536 addresses (10.0.0.0 to 10.0.255.255).

**Subnet**: a subdivision of the VPC in a specific Availability Zone.
- **Public subnet**: has a route to an Internet Gateway — resources here can reach the internet
- **Private subnet**: NO route to the internet — resources here are isolated (databases, internal services)

**Internet Gateway (IGW)**: connects your VPC to the internet. Attach one IGW per VPC for public subnets.

**NAT Gateway**: allows private subnet resources to reach the internet (for package installs, API calls) WITHOUT being reachable from the internet. Put NAT Gateway in a public subnet.

**Route Table**: rules for where network traffic is directed. Each subnet is associated with a route table.

```
Internet
    │
    ▼
Internet Gateway
    │
    ▼ (route 0.0.0.0/0 → IGW)
Public Subnet (10.0.1.0/24)
    │   → EC2 instances with public IPs
    │   → Load Balancer
    │
    ▼ (via NAT Gateway)
Private Subnet (10.0.2.0/24)
    │   → RDS databases
    │   → EC2 app servers (no public IP)
    │   → EKS worker nodes
```

### VPC CLI Commands

```bash
# Create a VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16
# Returns VpcId: vpc-12345678

# Create subnets
aws ec2 create-subnet \
  --vpc-id vpc-12345678 \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a
  # Returns SubnetId: subnet-public-a

aws ec2 create-subnet \
  --vpc-id vpc-12345678 \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ap-south-1a
  # Returns SubnetId: subnet-private-a

# Create and attach Internet Gateway
aws ec2 create-internet-gateway
# Returns InternetGatewayId: igw-12345678

aws ec2 attach-internet-gateway \
  --internet-gateway-id igw-12345678 \
  --vpc-id vpc-12345678

# Add route to Internet Gateway for the public subnet's route table
aws ec2 create-route \
  --route-table-id rtb-public-12345678 \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-12345678

# Create NAT Gateway (put in public subnet)
aws ec2 create-nat-gateway \
  --subnet-id subnet-public-a \
  --allocation-id eipalloc-12345678    # Elastic IP for NAT Gateway

# Add route to NAT Gateway for private subnet
aws ec2 create-route \
  --route-table-id rtb-private-12345678 \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-12345678

# List VPCs
aws ec2 describe-vpcs
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-12345678"
```

---

## Common Misunderstanding: "S3 is a filesystem"

**The misunderstanding:** "S3 works like a hard drive with folders."

**The reality:** S3 is an **object store**, not a filesystem. What looks like folders (`uploads/images/photo.jpg`) is actually just part of the object's key. There are no real directories — `uploads/` doesn't "exist" as an object.

Consequences:
- You can't move/rename objects efficiently (you must copy then delete — no atomic move)
- No partial file updates (you must re-upload the entire object to change one byte)
- Listing "folders" is a prefix search — expensive at massive scale
- No file locking — two processes can overwrite the same object simultaneously

S3 is phenomenal for what it is: append/replace storage for discrete objects (images, backups, logs, artifacts). Don't try to use it like a database or filesystem.

→ Continue to: `02-rds-eks-cloudwatch.md`
