# VPC — 01: Subnets and Routing

> **Last updated:** July 5, 2026
> **How public/private subnets work, route tables, and Internet Gateways — explained clearly.**

---

## What Is a Subnet?

A **subnet** is a subdivision of your VPC's IP range. You carve up your VPC CIDR into smaller CIDRs and assign each piece to a subnet.

```
VPC: 10.0.0.0/16 (65,536 IPs)

Divide into subnets:
  10.0.1.0/24  → Public Subnet AZ-a  (256 IPs)
  10.0.2.0/24  → Private Subnet AZ-a (256 IPs)
  10.0.3.0/24  → Public Subnet AZ-b  (256 IPs)
  10.0.4.0/24  → Private Subnet AZ-b (256 IPs)
  ... remaining IPs available for future subnets
```

Each subnet must be in exactly one Availability Zone. You can't span a subnet across AZs.

**AWS reserves 5 IPs in every subnet:**
```
In subnet 10.0.1.0/24:
  10.0.1.0   → Network address (reserved)
  10.0.1.1   → VPC Router (reserved)
  10.0.1.2   → DNS (reserved)
  10.0.1.3   → Future use (reserved)
  10.0.1.255 → Broadcast (reserved)

Usable IPs: 10.0.1.4 – 10.0.1.254  (251 usable, not 256)
```

---

## Internet Gateway (IGW)

An **Internet Gateway** is a VPC component that allows communication between your VPC and the internet.

Properties:
- One per VPC
- Horizontally scaled, highly available — it never becomes a bottleneck
- Free (you pay for data transfer, not the IGW itself)
- Does **1:1 NAT** — maps public IP of your EC2 to its private IP

```
EC2 has:
  Private IP: 10.0.1.50 (internal)
  Public IP:  52.66.123.45 (assigned by AWS, visible on internet)

When traffic goes OUT:
  EC2 → IGW: "I'm 10.0.1.50 sending this to the internet"
  IGW → Internet: "Sending from 52.66.123.45"

When traffic comes IN:
  Internet → IGW: "Packet for 52.66.123.45"
  IGW → EC2: "Packet for 10.0.1.50"
```

The IGW handles the IP translation (public ↔ private). EC2 itself only ever sees its private IP.

---

## Route Tables — The Core Concept

A **Route Table** is a set of rules that determines where network traffic goes.

Every subnet has a route table. The route table answers: **"When a packet is going to IP X, where should it go?"**

### Reading a Route Table

```
Route Table: public-subnet-rt

Destination     Target
0.0.0.0/0       igw-0123456789   ← Any IP → go to Internet Gateway
10.0.0.0/16     local            ← VPC-local IPs → stay within VPC
```

How to read this:
1. A packet going to `10.0.1.50` matches `10.0.0.0/16` → stays in VPC (local route)
2. A packet going to `8.8.8.8` doesn't match `10.0.0.0/16` → matches `0.0.0.0/0` → goes to IGW

The **most specific route wins** (longest prefix match).

### Public Subnet Route Table

```
Destination     Target
10.0.0.0/16     local
0.0.0.0/0       igw-xxxx         ← This is what makes it "public"
```

### Private Subnet Route Table

```
Destination     Target
10.0.0.0/16     local
                                  ← No 0.0.0.0/0 route → no internet access
```

Or if you want the private subnet to reach the internet (for downloads):
```
Destination     Target
10.0.0.0/16     local
0.0.0.0/0       nat-xxxxxxxx     ← Goes to NAT Gateway, not IGW
```

---

## Making a Subnet Public — Step by Step

A subnet is not "public" because of its name — it becomes public only when you:

**Step 1: Create and attach an Internet Gateway**

```bash
# Create IGW
aws ec2 create-internet-gateway
# Returns: InternetGatewayId: igw-0123456789abcdef0

# Attach to VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id igw-0123456789abcdef0 \
  --vpc-id vpc-0123456789abcdef0
```

**Step 2: Create a route table and add a route to IGW**

```bash
# Create a new route table for public subnets
aws ec2 create-route-table --vpc-id vpc-0123456789abcdef0
# Returns: RouteTableId: rtb-0123456789abcdef0

# Add route: 0.0.0.0/0 → IGW
aws ec2 create-route \
  --route-table-id rtb-0123456789abcdef0 \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-0123456789abcdef0
```

**Step 3: Associate the route table with the subnet**

```bash
aws ec2 associate-route-table \
  --route-table-id rtb-0123456789abcdef0 \
  --subnet-id subnet-0123456789abcdef0
```

Now any EC2 in that subnet can reach the internet (if they also have a public IP or Elastic IP).

**Step 4: Enable auto-assign public IP on the subnet**

```bash
aws ec2 modify-subnet-attribute \
  --subnet-id subnet-0123456789abcdef0 \
  --map-public-ip-on-launch
```

Without this, EC2 instances launched in the subnet won't get a public IP.

---

## Public IP vs Elastic IP vs Private IP

```
Private IP    → Assigned from the subnet CIDR, always stays the same
               → Used for internal VPC communication
               → Example: 10.0.1.50

Public IP     → Assigned by AWS automatically, changes when you stop/start EC2
               → Free while instance is running, charged if unused
               → Used for internet access

Elastic IP    → A static public IP that YOU control
               → Doesn't change when you stop/start
               → Stays assigned to your account even when not in use
               → Charged if NOT attached to a running instance (to prevent waste)
               → Use when you need a permanent IP (whitelist in firewalls)
```

```bash
# Allocate an Elastic IP
aws ec2 allocate-address --domain vpc

# Associate it with an EC2 instance
aws ec2 associate-address \
  --instance-id i-1234567890abcdef0 \
  --allocation-id eipalloc-0123456789abcdef0

# Disassociate
aws ec2 disassociate-address --association-id eipassoc-xxxxx

# Release (free up the EIP)
aws ec2 release-address --allocation-id eipalloc-0123456789abcdef0
```

---

## Creating a VPC and Subnets (CLI)

```bash
# 1. Create VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16
# Returns: VpcId: vpc-0123456789abcdef0

# Tag it
aws ec2 create-tags \
  --resources vpc-0123456789abcdef0 \
  --tags Key=Name,Value=vault-vpc

# 2. Create subnets
# Public subnet in AZ-a
aws ec2 create-subnet \
  --vpc-id vpc-0123456789abcdef0 \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a
# Tag as "Public Subnet AZ-a"

# Private subnet in AZ-a
aws ec2 create-subnet \
  --vpc-id vpc-0123456789abcdef0 \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ap-south-1a

# Public subnet in AZ-b
aws ec2 create-subnet \
  --vpc-id vpc-0123456789abcdef0 \
  --cidr-block 10.0.3.0/24 \
  --availability-zone ap-south-1b

# Private subnet in AZ-b
aws ec2 create-subnet \
  --vpc-id vpc-0123456789abcdef0 \
  --cidr-block 10.0.4.0/24 \
  --availability-zone ap-south-1b

# 3. Create and attach IGW
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway \
  --internet-gateway-id igw-xxxx \
  --vpc-id vpc-0123456789abcdef0

# 4. Create public route table and add IGW route
aws ec2 create-route-table --vpc-id vpc-0123456789abcdef0
aws ec2 create-route \
  --route-table-id rtb-public \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-xxxx

# 5. Associate public subnets with public route table
aws ec2 associate-route-table \
  --route-table-id rtb-public \
  --subnet-id subnet-public-a
aws ec2 associate-route-table \
  --route-table-id rtb-public \
  --subnet-id subnet-public-b

# Private subnets use the "main" route table (has only the local route)
```

---

## Common Mistakes

### Mistake 1: Created the subnet and named it "Public" but it has no IGW route

The name is just a label. The subnet becomes public only when you add the `0.0.0.0/0 → IGW` route AND associate that route table with the subnet.

### Mistake 2: EC2 in public subnet can't reach the internet

Checklist:
```
□ Subnet route table has 0.0.0.0/0 → IGW?
□ EC2 has a public IP or Elastic IP?
□ Security Group allows outbound 80/443?
□ NACL allows outbound 80/443 AND inbound 1024-65535 (ephemeral ports)?
```

### Mistake 3: EC2 in private subnet can reach the internet unexpectedly

```
Possible cause: Private subnet's route table has 0.0.0.0/0 → IGW
Fix: Route table should not have an IGW route. Only NAT Gateway or no route.
```

→ Continue to: `02-security-groups.md`
