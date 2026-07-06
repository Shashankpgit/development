# VPC — 06: VPC in Practice

> **Last updated:** July 5, 2026
> **Build a complete production-grade 3-tier VPC from scratch, step by step.**

---

## What We're Building

A complete 3-tier VPC for a web application:

```
Region: ap-south-1

                        Internet
                           │
                     Internet Gateway
                           │
          ┌────────────────┼────────────────┐
          │           PUBLIC TIER           │
          │  ┌──────────────────────────┐   │
          │  │  ALB (Load Balancer)      │   │
          │  └──────────────────────────┘   │
          │  ┌────────────┐ ┌────────────┐  │
          │  │ NAT GW a   │ │ NAT GW b   │  │
          │  │ (AZ-a)     │ │ (AZ-b)     │  │
          │  └────────────┘ └────────────┘  │
          └────────────────────────────────┘
          ┌────────────────────────────────┐
          │          APP TIER              │
          │  ┌──────────┐  ┌──────────┐   │
          │  │  EC2/ECS │  │  EC2/ECS │   │
          │  │  (AZ-a)  │  │  (AZ-b)  │   │
          │  └──────────┘  └──────────┘   │
          └────────────────────────────────┘
          ┌────────────────────────────────┐
          │          DB TIER               │
          │  ┌──────────┐  ┌──────────┐   │
          │  │  RDS     │  │  RDS     │   │
          │  │ Primary  │  │ Standby  │   │
          │  │  (AZ-a)  │  │  (AZ-b)  │   │
          │  └──────────┘  └──────────┘   │
          └────────────────────────────────┘

VPC CIDR: 10.0.0.0/16

Subnets:
  10.0.1.0/24  → public-az-a   (ALB, NAT GW)
  10.0.2.0/24  → public-az-b   (ALB, NAT GW)
  10.0.3.0/24  → app-az-a      (EC2/ECS)
  10.0.4.0/24  → app-az-b      (EC2/ECS)
  10.0.5.0/24  → db-az-a       (RDS Primary)
  10.0.6.0/24  → db-az-b       (RDS Standby)
```

---

## Step 1: Create the VPC

**Console:**
1. VPC → Create VPC
2. VPC Only (not VPC and more)
3. Name: `vault-vpc`
4. CIDR: `10.0.0.0/16`
5. No IPv6
6. Tenancy: Default

**CLI:**
```bash
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=vault-vpc

# Enable DNS hostnames (required for RDS, SSM, some services)
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames

echo "VPC ID: $VPC_ID"
```

---

## Step 2: Create Subnets

```bash
# Public subnets
PUBLIC_A=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a \
  --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PUBLIC_A --tags Key=Name,Value=vault-public-az-a

PUBLIC_B=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ap-south-1b \
  --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PUBLIC_B --tags Key=Name,Value=vault-public-az-b

# App subnets (private)
APP_A=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.3.0/24 \
  --availability-zone ap-south-1a \
  --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $APP_A --tags Key=Name,Value=vault-app-az-a

APP_B=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.4.0/24 \
  --availability-zone ap-south-1b \
  --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $APP_B --tags Key=Name,Value=vault-app-az-b

# DB subnets (private)
DB_A=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.5.0/24 \
  --availability-zone ap-south-1a \
  --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $DB_A --tags Key=Name,Value=vault-db-az-a

DB_B=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.6.0/24 \
  --availability-zone ap-south-1b \
  --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $DB_B --tags Key=Name,Value=vault-db-az-b

# Enable auto-assign public IP on public subnets
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_A --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_B --map-public-ip-on-launch
```

---

## Step 3: Internet Gateway

```bash
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=vault-igw

aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID

echo "IGW ID: $IGW_ID"
```

---

## Step 4: NAT Gateways (One Per AZ)

```bash
# Allocate Elastic IPs
EIP_A=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
EIP_B=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

# Create NAT Gateways in PUBLIC subnets
NAT_A=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_A \
  --allocation-id $EIP_A \
  --query 'NatGateway.NatGatewayId' --output text)

NAT_B=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_B \
  --allocation-id $EIP_B \
  --query 'NatGateway.NatGatewayId' --output text)

# Wait for them to be available
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_A $NAT_B
echo "NAT Gateways ready"
```

---

## Step 5: Route Tables

```bash
# Public route table (used by public subnets)
RT_PUBLIC=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $RT_PUBLIC --tags Key=Name,Value=vault-rt-public

# Add route: all internet traffic → IGW
aws ec2 create-route \
  --route-table-id $RT_PUBLIC \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Associate public subnets
aws ec2 associate-route-table --route-table-id $RT_PUBLIC --subnet-id $PUBLIC_A
aws ec2 associate-route-table --route-table-id $RT_PUBLIC --subnet-id $PUBLIC_B

# Private route table AZ-a (app + db in AZ-a use NAT-a)
RT_PRIVATE_A=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $RT_PRIVATE_A --tags Key=Name,Value=vault-rt-private-az-a
aws ec2 create-route \
  --route-table-id $RT_PRIVATE_A \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_A
aws ec2 associate-route-table --route-table-id $RT_PRIVATE_A --subnet-id $APP_A
aws ec2 associate-route-table --route-table-id $RT_PRIVATE_A --subnet-id $DB_A

# Private route table AZ-b (app + db in AZ-b use NAT-b)
RT_PRIVATE_B=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $RT_PRIVATE_B --tags Key=Name,Value=vault-rt-private-az-b
aws ec2 create-route \
  --route-table-id $RT_PRIVATE_B \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_B
aws ec2 associate-route-table --route-table-id $RT_PRIVATE_B --subnet-id $APP_B
aws ec2 associate-route-table --route-table-id $RT_PRIVATE_B --subnet-id $DB_B
```

---

## Step 6: Security Groups

```bash
# Security Group for ALB (public internet → ALB)
SG_ALB=$(aws ec2 create-security-group \
  --group-name vault-sg-alb \
  --description "ALB security group" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ALB --protocol tcp --port 80  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ALB --protocol tcp --port 443 --cidr 0.0.0.0/0

# Security Group for App Servers (only ALB can reach them)
SG_APP=$(aws ec2 create-security-group \
  --group-name vault-sg-app \
  --description "App server security group" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_APP \
  --protocol tcp --port 8080 \
  --source-group $SG_ALB    ← only ALB can reach app servers

# Security Group for RDS (only app servers can reach it)
SG_RDS=$(aws ec2 create-security-group \
  --group-name vault-sg-rds \
  --description "RDS security group" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_RDS \
  --protocol tcp --port 5432 \
  --source-group $SG_APP    ← only app servers can reach RDS
```

---

## Step 7: S3 Gateway Endpoint (Free — Do This)

```bash
aws ec2 create-vpc-endpoint \
  --vpc-id $VPC_ID \
  --service-name com.amazonaws.ap-south-1.s3 \
  --route-table-ids $RT_PRIVATE_A $RT_PRIVATE_B $RT_PUBLIC
```

Now EC2 in private subnets can access S3 without going through NAT Gateway (saves cost).

---

## Verify Your Setup

```bash
# List all subnets in the VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,AZ:AvailabilityZone,SubnetId:SubnetId}' \
  --output table

# List route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],Routes:Routes[*].DestinationCidrBlock}' \
  --output table

# List security groups
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[*].{Name:GroupName,Id:GroupId}' \
  --output table
```

---

## Common Issues and Fixes

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| EC2 in public subnet unreachable | No public IP | Enable auto-assign public IP on subnet |
| EC2 in public subnet unreachable | SG blocks SSH | Add inbound TCP 22 from your IP |
| Private EC2 can't reach internet | Route table missing NAT route | Add 0.0.0.0/0 → nat-gw in private RT |
| RDS not reachable from app | SG missing | Add inbound 5432 from app SG to RDS SG |
| EC2 can't reach S3 | No endpoint, no NAT | Add S3 VPC endpoint or fix NAT route |
| Subnet association wrong | Wrong route table | Re-associate subnet with correct RT |

→ You've completed the VPC section. Continue to: `../ec2/00-mental-model.md`
