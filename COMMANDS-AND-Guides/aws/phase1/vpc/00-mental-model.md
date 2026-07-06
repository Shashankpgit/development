# VPC — 00: Mental Model

> **Last updated:** July 5, 2026
> **Phase:** 1 — Foundation
> **Read this first before any other VPC file.**

---

## What Is a VPC?

When you sign up for AWS, you are sharing the same physical hardware as thousands of other AWS customers. But your servers, databases, and resources need to be completely isolated from theirs.

A **VPC (Virtual Private Cloud)** is your own **private, isolated section of the AWS network**.

Think of it as renting a floor in a large office building:
- The building (AWS network) has thousands of floors for thousands of companies
- Your floor (VPC) is completely yours — other companies can't see your floor
- Inside your floor, you decide the layout: private offices (private subnets), reception area (public subnet)
- The building's security (AWS) handles physical security; you handle your floor's internal rules

---

## The CIDR Block — Your IP Range

Every VPC is assigned a **CIDR block** — a range of private IP addresses that resources inside the VPC will use.

```
CIDR:  10.0.0.0/16

This means:
  → First 16 bits are fixed: 10.0 (the network portion)
  → Last 16 bits are free:   0.0 - 255.255 (65,536 possible IPs)
```

**Reading CIDR notation:**

```
10.0.0.0/8   → 10.x.x.x     → 16,777,216 IPs (huge)
10.0.0.0/16  → 10.0.x.x     → 65,536 IPs     (typical VPC)
10.0.1.0/24  → 10.0.1.x     → 256 IPs        (typical subnet)
10.0.1.0/28  → 10.0.1.0–15  → 16 IPs         (small subnet)
```

The `/N` number means "the first N bits are locked." The more bits locked, the smaller the range.

**AWS-allowed private IP ranges for VPCs:**
```
10.0.0.0    – 10.255.255.255   (10.0.0.0/8 and smaller)
172.16.0.0  – 172.31.255.255   (172.16.0.0/12 and smaller)
192.168.0.0 – 192.168.255.255  (192.168.0.0/16 and smaller)
```

**Common VPC CIDR:** `10.0.0.0/16` — enough for 65K IPs, easy to subnet.

---

## The Core Building Blocks

```
VPC (10.0.0.0/16)
  │
  ├── Availability Zone A (ap-south-1a)
  │     ├── Public Subnet  (10.0.1.0/24)   ← Resources here CAN reach internet
  │     └── Private Subnet (10.0.2.0/24)   ← Resources here CANNOT reach internet
  │
  ├── Availability Zone B (ap-south-1b)
  │     ├── Public Subnet  (10.0.3.0/24)
  │     └── Private Subnet (10.0.4.0/24)
  │
  ├── Internet Gateway                      ← Door between VPC and internet
  ├── NAT Gateway (in public subnet)        ← Lets private subnet go OUT to internet
  └── Route Tables                          ← Rules for where traffic goes
```

**Public vs Private Subnet — the ONLY difference:**

A "public subnet" is just a subnet whose **route table has a route to the Internet Gateway**.
A "private subnet" is just a subnet whose **route table has NO route to the Internet Gateway**.

That's it. There's nothing magic about the words "public" or "private" — it's entirely about the route table.

---

## How Traffic Flows

### Scenario: Someone visits your website

```
User (internet) → 203.0.113.10
    ↓ DNS resolves api.vault.example.com to your public IP
Internet Gateway (translates public IP → private IP of EC2)
    ↓
EC2 in Public Subnet (10.0.1.50)
    ↓ EC2 queries database
Private Subnet (10.0.2.100) → RDS
```

The EC2 web server is in the public subnet (visible from internet).
The database is in the private subnet (invisible from internet).

### Scenario: EC2 in private subnet downloads a package

```
EC2 in Private Subnet (10.0.2.50) → wants to reach apt.ubuntu.com
    ↓ route table says: 0.0.0.0/0 → NAT Gateway
NAT Gateway (10.0.1.25, in public subnet)
    ↓ NAT Gateway has a route to Internet Gateway
Internet Gateway
    ↓
Internet (apt.ubuntu.com)
```

Traffic goes: Private EC2 → NAT → IGW → Internet
Response goes: Internet → IGW → NAT → Private EC2

The internet server only sees the NAT Gateway's public IP, never the private EC2's IP.

---

## Why Multiple AZs?

Each Availability Zone is a physically separate data center in the region (different building, different power, different network).

If you put everything in one AZ and it has a power outage → your app is down.

If you spread across multiple AZs, one AZ fails → traffic automatically goes to the other AZ.

```
Your App:
  AZ-a: Web server, DB Primary
  AZ-b: Web server, DB Standby (Multi-AZ)

AZ-a fails → Load Balancer routes to AZ-b web server
             DB automatically fails over to AZ-b
             Downtime: seconds
```

**Best practice:** Always put resources in at least 2 AZs.

---

## Default VPC

Every new AWS account comes with a **default VPC** in each region. It has:
- CIDR: `172.31.0.0/16`
- One public subnet per AZ
- An Internet Gateway already attached
- All instances launched get a public IP by default

The default VPC is fine for experiments and learning. **For production, create a custom VPC** — you control the CIDR, subnet layout, and security.

---

## What's Next

| File | What It Covers |
|------|---------------|
| `01-subnets-and-routing.md` | How route tables work, IGW, making subnets public/private |
| `02-security-groups.md` | Stateful firewall for individual resources |
| `03-network-acls.md` | Stateless firewall at the subnet level |
| `04-nat-gateway.md` | Giving internet access to private subnets |
| `05-vpc-connectivity.md` | Peering, Transit Gateway, Endpoints, VPN |
| `06-vpc-in-practice.md` | Build a complete 3-tier VPC from scratch |

→ Continue to: `01-subnets-and-routing.md`
