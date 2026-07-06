# VPC — 04: NAT Gateway

> **Last updated:** July 5, 2026
> **Why private subnets need a NAT Gateway, how it works, and how to set it up.**

---

## The Problem

Your database and application servers are in private subnets — they have no route to the internet, and that's intentional (security: you don't want them directly accessible from the internet).

But they still need to reach the internet for:
- Downloading OS updates (`apt-get update`)
- Pulling Docker images
- Calling external APIs (payment gateways, notification services)
- Sending data to CloudWatch, S3, or other AWS services (if not using VPC endpoints)

**The challenge:** Allow private subnet resources to INITIATE connections to the internet, but prevent the internet from INITIATING connections to them.

This is exactly what a **NAT Gateway** does.

---

## What Is NAT?

**NAT = Network Address Translation**

It translates private IP addresses to a public IP address so traffic can flow through the internet.

```
Private EC2 (10.0.2.50) → wants to reach google.com (142.250.182.46)

Without NAT: The packet is from 10.0.2.50. Internet doesn't know what 10.0.2.50 is
             (private IPs are not routable on the internet)

With NAT: 
  EC2 (10.0.2.50) sends packet to NAT Gateway
  NAT Gateway replaces source IP: 10.0.2.50 → 52.66.100.200 (NAT's public Elastic IP)
  Packet goes out to internet: "From 52.66.100.200, To 142.250.182.46"
  
  Google responds to 52.66.100.200
  NAT Gateway receives the response
  NAT Gateway translates back: 52.66.100.200 → 10.0.2.50
  Delivers to EC2
```

The internet only ever sees the NAT Gateway's public IP, never the private EC2.

---

## NAT Gateway vs NAT Instance

AWS offers two options:

| | NAT Gateway (managed) | NAT Instance (EC2) |
|--|----------------------|-------------------|
| Management | AWS manages everything | You manage the EC2 |
| Availability | Highly available within an AZ | Single point of failure |
| Bandwidth | Scales automatically up to 100Gbps | Limited by instance type |
| Cost | ~$0.045/hr + data transfer | EC2 costs + maintenance |
| Use for production | Yes | No — legacy approach |

**Always use NAT Gateway for production.**

---

## Where to Place the NAT Gateway

**NAT Gateway goes in a PUBLIC subnet.**

This confuses people: "Why is the NAT Gateway in the public subnet when it serves private subnets?"

Because the NAT Gateway needs to reach the internet, it must be in a subnet that has a route to the Internet Gateway.

```
The flow:
Private subnet EC2 → NAT Gateway (in public subnet) → Internet Gateway → Internet

If NAT Gateway were in a private subnet:
  It would need another NAT to get to the internet → circular dependency
```

NAT Gateway needs:
1. To be in a **public subnet** (subnet with IGW route)
2. An **Elastic IP** attached (for its outbound public IP)
3. Private subnet's **route table** pointing 0.0.0.0/0 to the NAT Gateway

---

## Setting Up a NAT Gateway (Step by Step)

### Step 1: Allocate an Elastic IP

```bash
aws ec2 allocate-address --domain vpc
# Returns: AllocationId: eipalloc-0123456789abcdef0
#          PublicIp: 52.66.100.200
```

### Step 2: Create NAT Gateway in the public subnet

```bash
aws ec2 create-nat-gateway \
  --subnet-id subnet-public-az-a \         ← PUBLIC subnet
  --allocation-id eipalloc-0123456789abcdef0

# Returns: NatGatewayId: nat-0123456789abcdef0
# Wait for it to become "available" (~60 seconds)
aws ec2 describe-nat-gateways --nat-gateway-ids nat-0123456789abcdef0
```

### Step 3: Update private subnet's route table

```bash
# Add route: 0.0.0.0/0 → NAT Gateway
aws ec2 create-route \
  --route-table-id rtb-private-az-a \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-0123456789abcdef0
```

### Step 4: Test from a private EC2

```bash
# SSH into a private EC2 (via bastion host)
curl https://checkip.amazonaws.com
# Returns: 52.66.100.200 ← the NAT Gateway's IP, not the EC2's private IP

# Test package download
sudo apt-get update   # should work
```

---

## High Availability: One NAT Gateway Per AZ

**A NAT Gateway exists in one AZ.** If that AZ goes down, the NAT Gateway is unavailable.

For production: create one NAT Gateway **per AZ**, and configure each private subnet's route table to use the NAT Gateway in the **same AZ**.

```
AZ-a:
  Public Subnet a → NAT Gateway a (EIP: 52.66.100.201)
  Private Subnet a → Route: 0.0.0.0/0 → nat-a

AZ-b:
  Public Subnet b → NAT Gateway b (EIP: 52.66.100.202)
  Private Subnet b → Route: 0.0.0.0/0 → nat-b

If AZ-a goes down:
  Private Subnet a is unavailable (expected — AZ failure)
  Private Subnet b still works via nat-b
```

Cost: ~$0.045/hr × 2 NAT Gateways = ~$65/month. For production HA, this is necessary.

For dev/test: one NAT Gateway is fine (accept the AZ risk to save cost).

---

## NAT Gateway vs VPC Endpoint

Before spending money on NAT Gateway data transfer charges, check if the AWS service you're calling has a **VPC Endpoint**.

```
Private EC2 → S3 (via NAT Gateway):
  Traffic leaves VPC → goes to internet → comes back into AWS
  Cost: NAT data transfer charges + S3 data transfer charges

Private EC2 → S3 (via VPC Gateway Endpoint):
  Traffic stays inside AWS network
  Cost: FREE (Gateway endpoints for S3 and DynamoDB are free)
```

Always use VPC Endpoints for S3 and DynamoDB from private subnets — it's free and faster.

---

## Checking NAT Gateway Connectivity

```bash
# List your NAT Gateways
aws ec2 describe-nat-gateways

# Check CloudWatch metrics for NAT Gateway
# ErrorPortAllocation → running out of NAT ports (source port exhaustion)
# PacketsDropCount    → packets being dropped

# Check private route table includes NAT Gateway route
aws ec2 describe-route-tables --route-table-ids rtb-private-xxxx

# Delete a NAT Gateway (and release EIP separately)
aws ec2 delete-nat-gateway --nat-gateway-id nat-0123456789abcdef0
aws ec2 release-address --allocation-id eipalloc-0123456789abcdef0
```

---

## Summary: The Traffic Flow

```
                       INTERNET
                          │
                    ┌─────┴─────┐
                    │    IGW    │
                    └─────┬─────┘
                          │
   ┌──────────────────────┼──────────────────────┐
   │       PUBLIC SUBNET  │                      │
   │  ┌─────────────────┐ │ ┌─────────────────┐  │
   │  │   Bastion EC2   │ │ │  NAT Gateway    │  │
   │  │  (SSH access)   │ │ │  (EIP attached) │  │
   │  └─────────────────┘ │ └────────┬────────┘  │
   │                      │          │            │
   └──────────────────────┼──────────┼────────────┘
                          │          │ route: 0.0.0.0/0 → nat-gw
   ┌──────────────────────┼──────────┼────────────┐
   │      PRIVATE SUBNET  │          │            │
   │  ┌─────────────────┐ │ ┌────────┴────────┐   │
   │  │   App Server    │─┘ │  RDS Database   │   │
   │  └─────────────────┘   └─────────────────┘   │
   │                                               │
   └───────────────────────────────────────────────┘
```

→ Continue to: `05-vpc-connectivity.md`
