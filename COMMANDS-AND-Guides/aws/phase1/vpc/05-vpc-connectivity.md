# VPC — 05: VPC Connectivity

> **Last updated:** July 5, 2026
> **VPC Peering, Transit Gateway, VPC Endpoints, Site-to-Site VPN, Direct Connect — when to use each.**

---

## The Problem: Connecting Networks

As your infrastructure grows, you'll need to connect:
- Two VPCs together (dev VPC ↔ prod VPC, or microservices in separate VPCs)
- Your on-premises office to AWS
- Private subnets to AWS services (S3, DynamoDB) without internet traffic

---

## VPC Peering

**VPC Peering** creates a private network connection between two VPCs. Traffic between them stays on AWS's private network — no internet.

```
VPC A (10.0.0.0/16) ←──── Peering Connection ────→ VPC B (172.16.0.0/16)
```

### Key Rules

**CIDRs must not overlap:**
```
VPC A: 10.0.0.0/16
VPC B: 10.0.0.0/16   ← CANNOT peer — same CIDR
VPC B: 172.16.0.0/16 ← CAN peer — different CIDR
```

**Peering is NOT transitive:**
```
VPC A ← peered → VPC B ← peered → VPC C

Does VPC A automatically have access to VPC C? NO.
A can reach B. B can reach C. A cannot reach C.
To connect A and C: create a SEPARATE peering connection between A and C.
```

### Setting Up VPC Peering

```bash
# Step 1: Create peering connection (from VPC A)
aws ec2 create-vpc-peering-connection \
  --vpc-id vpc-a-id \
  --peer-vpc-id vpc-b-id \
  --peer-region ap-south-1     # only needed for cross-region peering

# Step 2: Accept the connection (from VPC B)
aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id pcx-0123456789abcdef0

# Step 3: Add routes in BOTH VPCs
# In VPC A's route table: 172.16.0.0/16 → pcx-xxxx
aws ec2 create-route \
  --route-table-id rtb-vpc-a \
  --destination-cidr-block 172.16.0.0/16 \
  --vpc-peering-connection-id pcx-0123456789abcdef0

# In VPC B's route table: 10.0.0.0/16 → pcx-xxxx
aws ec2 create-route \
  --route-table-id rtb-vpc-b \
  --destination-cidr-block 10.0.0.0/16 \
  --vpc-peering-connection-id pcx-0123456789abcdef0

# Step 4: Update Security Groups to allow traffic from the other VPC's CIDR
```

**When to use:** Small number of VPCs that need to talk directly (2-3 VPCs). Simple, free within same region.

---

## Transit Gateway

**Transit Gateway** is a central hub that connects multiple VPCs and on-premises networks.

```
Without TGW (mesh of peering connections):
VPC A ←→ VPC B ←→ VPC C ←→ VPC D
  ↑_________↗↑__________↗       (need 6 peering connections for 4 VPCs)

With TGW (hub-and-spoke):
VPC A ─┐
VPC B ─┤── Transit Gateway ──── On-Prem Network
VPC C ─┤
VPC D ─┘
       (4 attachments, each VPC only connects to TGW)
```

**Transit Gateway is transitive** — traffic can flow through it from any attached VPC to any other.

### When to Use TGW vs Peering

| | VPC Peering | Transit Gateway |
|--|------------|----------------|
| Scale | Few VPCs (2-5) | Many VPCs (6+) |
| Transitive routing | No | Yes |
| Cost | Free within region | $0.05/hr per attachment + data |
| Cross-region | Yes (charged) | Yes (charged) |
| On-premises connection | No | Yes (VPN/Direct Connect attach) |
| Complexity | Simple | More complex |

---

## VPC Endpoints — Access AWS Services Without Internet

A **VPC Endpoint** lets resources in your private subnet access AWS services (S3, DynamoDB, etc.) without traffic going through the internet or NAT Gateway.

### Why This Matters

```
Without VPC endpoint:
  Private EC2 → NAT Gateway → Internet → S3
  Cost: NAT data transfer charges + slower

With VPC endpoint:
  Private EC2 → VPC Endpoint → S3 (stays inside AWS network)
  Cost: Free (for Gateway endpoints) + faster + more secure
```

### Two Types of VPC Endpoints

**Gateway Endpoint** (for S3 and DynamoDB only):
- Free
- Works by adding an entry to your route table
- No interface created — just a routing rule

```bash
# Create an S3 Gateway Endpoint
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-0123456789abcdef0 \
  --service-name com.amazonaws.ap-south-1.s3 \
  --route-table-ids rtb-private-az-a rtb-private-az-b
```

After creating it, your route table has a new entry:
```
Destination                                     Target
pl-63a5400a (com.amazonaws.ap-south-1.s3)      vpce-0123456789
```

Now any traffic to S3 from private subnets goes through the endpoint, not internet.

**Interface Endpoint** (for all other AWS services):
- Costs ~$0.01/hr per AZ + data transfer
- Creates an **ENI** (Elastic Network Interface) with a private IP in your subnet
- The ENI is the private IP for the AWS service within your VPC
- Supports VPC Endpoint Policies (fine-grained access control)

```bash
# Create an SSM Interface Endpoint (to use Systems Manager from private instances)
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-0123456789abcdef0 \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.ap-south-1.ssm \
  --subnet-ids subnet-private-az-a subnet-private-az-b \
  --security-group-ids sg-endpoints

# For SSM to work, you also need endpoints for:
# com.amazonaws.ap-south-1.ssmmessages
# com.amazonaws.ap-south-1.ec2messages
```

### Common Interface Endpoints

| Service | Why You Need It |
|---------|----------------|
| `ssm` | Session Manager (SSH-less access to private EC2) |
| `ssmmessages` | Required with SSM |
| `ec2messages` | Required with SSM |
| `secretsmanager` | Access Secrets Manager from private subnet |
| `kms` | KMS calls without internet |
| `ecr.api` + `ecr.dkr` | Pull ECR images from private ECS/EKS |
| `logs` | CloudWatch Logs from private instances |
| `execute-api` | Invoke API Gateway from private VPC |

---

## Bastion Host

A **Bastion Host** (also called a Jump Box) is an EC2 instance in a public subnet that you SSH into, then SSH from there to private instances.

```
Your laptop → SSH → Bastion (public subnet) → SSH → Private EC2
```

```bash
# Connect to bastion
ssh -i key.pem ec2-user@bastion-public-ip

# From bastion, connect to private EC2
ssh -i key.pem ec2-user@10.0.2.50

# Or use SSH agent forwarding (so you don't need key on bastion)
ssh -A -i key.pem ec2-user@bastion-public-ip
# then:
ssh ec2-user@10.0.2.50
```

**Better alternative: AWS Systems Manager Session Manager**
- No bastion needed, no port 22 open
- Works via SSM Agent on EC2 + VPC Interface Endpoint
- Complete audit trail in CloudTrail
- See `05-iam-in-practice.md` for setup

---

## Site-to-Site VPN

Connect your on-premises network to your AWS VPC over the internet using encrypted tunnels (IPSec).

```
Your Office Network (192.168.0.0/24)
    └── Customer Gateway (your VPN device/router)
            ↕ IPSec encrypted tunnel (over internet)
    AWS VPC
    └── Virtual Private Gateway (AWS side)
```

```bash
# Create Customer Gateway (your VPN device)
aws ec2 create-customer-gateway \
  --type ipsec.1 \
  --public-ip YOUR_VPN_DEVICE_PUBLIC_IP \
  --bgp-asn 65000

# Create Virtual Private Gateway (AWS side)
aws ec2 create-vpn-gateway --type ipsec.1

# Attach VGW to VPC
aws ec2 attach-vpn-gateway \
  --vpn-gateway-id vgw-xxxx \
  --vpc-id vpc-0123456789abcdef0

# Create the VPN connection
aws ec2 create-vpn-connection \
  --type ipsec.1 \
  --customer-gateway-id cgw-xxxx \
  --vpn-gateway-id vgw-xxxx

# Enable route propagation on your route tables
aws ec2 enable-vgw-route-propagation \
  --route-table-id rtb-xxxx \
  --gateway-id vgw-xxxx
```

**Properties:**
- Setup in hours (no physical cables)
- Goes over internet (variable latency)
- Redundant: AWS provides two tunnels per connection (use both for HA)

---

## AWS Direct Connect

A **dedicated private fiber connection** from your on-premises data center to AWS. NOT over the internet.

```
Your Data Center ──── Dedicated fiber ──── AWS Direct Connect Location ──── AWS
                       (1Gbps or 10Gbps)         (physical cabling)
```

**When to use Direct Connect over VPN:**
- Consistent, predictable latency (VPN latency varies)
- High bandwidth (1–100 Gbps) — too much data for internet
- Regulatory requirement (data must not traverse public internet)
- Predictable cost (vs variable internet costs at high bandwidth)

**Setup time:** Weeks to months (requires physical cabling to a DX location).

---

## Connectivity Decision Tree

```
Need to connect two VPCs?
  ├── Few VPCs (≤5) with no need for shared on-prem access → VPC Peering
  └── Many VPCs or need on-prem access → Transit Gateway

Need to connect on-premises to AWS?
  ├── Quick setup, encrypt over internet, variable latency → Site-to-Site VPN
  └── Consistent latency, high bandwidth, dedicated → Direct Connect
  └── Both (Direct Connect primary, VPN as failover) → Use both

Need to access S3/DynamoDB from private subnet?
  └── VPC Gateway Endpoint (free)

Need to access other AWS services from private subnet?
  └── VPC Interface Endpoint (paid, ~$0.01/hr per AZ)
```

→ Continue to: `06-vpc-in-practice.md`
