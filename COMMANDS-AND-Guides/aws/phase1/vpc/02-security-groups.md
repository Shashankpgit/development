# VPC — 02: Security Groups

> **Last updated:** July 5, 2026
> **The stateful firewall that protects individual resources — EC2, RDS, Lambda, etc.**

---

## What Is a Security Group?

A **Security Group** is a virtual firewall attached to an individual AWS resource (EC2 instance, RDS database, Lambda, etc.). It controls what traffic is allowed IN and OUT.

Key properties:
- **Attached to a resource** (not a subnet — that's a NACL)
- **Stateful** — if you allow inbound traffic, the response is automatically allowed outbound (no need to write a return rule)
- **Allow-only** — you can only allow traffic, never deny. To block traffic, simply don't allow it
- A resource can have **multiple security groups** (rules from all groups are combined)

---

## Stateful — What This Actually Means

This is the most important concept. Let's be very clear.

**Scenario:** Your EC2 server receives a request from a user.

```
User's laptop (1.2.3.4) → HTTP request → EC2 (port 80)
```

The inbound journey:
```
Inbound rule: Allow TCP port 80 from 0.0.0.0/0
→ Request passes through to EC2
```

The outbound (response) journey:

With a **stateful** firewall (Security Group):
```
EC2 sends response back to 1.2.3.4 on port 54321 (ephemeral port)
→ Security Group: "I saw this connection come in — automatically allow the response out"
→ No outbound rule needed for the response
```

You only need to think about "what traffic am I INITIATING or ACCEPTING?"

---

## Rules Anatomy

A security group rule has these fields:

```
Type     → HTTP, HTTPS, SSH, Custom TCP, etc. (just a label for common protocols)
Protocol → TCP, UDP, ICMP, All
Port     → A single port or a range (e.g., 8080 or 8000-9000)
Source   → WHERE the traffic comes from (inbound)
           or WHERE traffic is going to (outbound)
           Options: CIDR (0.0.0.0/0), another Security Group ID, My IP
```

---

## Inbound Rules

**Inbound rules control what traffic is ALLOWED TO REACH your resource.**

Default: **No inbound traffic allowed** (all inbound blocked unless you add a rule).

### Common Inbound Rule Patterns

```
Web server (public-facing):
  HTTP   TCP  80   0.0.0.0/0          → Allow all internet traffic on port 80
  HTTPS  TCP  443  0.0.0.0/0          → Allow all internet traffic on port 443
  SSH    TCP  22   YOUR_IP/32         → Allow SSH only from your IP

RDS database:
  MySQL  TCP  3306  sg-webapp-id      → Allow MySQL connections from the webapp SG

Internal API server:
  Custom TCP  8080  sg-alb-id         → Allow traffic only from the load balancer SG

Redis cache:
  Custom TCP  6379  sg-api-servers-id → Allow Redis from API servers only
```

---

## Outbound Rules

**Outbound rules control what traffic your resource is ALLOWED TO INITIATE.**

Default: **All outbound traffic is allowed** (default outbound rule: `All traffic → 0.0.0.0/0`).

Why all-outbound is usually fine:
- EC2 instances need to reach package repositories, external APIs, etc.
- Since the SG is stateful, you don't need outbound rules for responses to inbound requests

When to restrict outbound:
- Compliance requirements (e.g., EC2 should ONLY talk to the database, nothing else)
- Security hardening (prevent compromised instance from calling home)

```
Restricted outbound example (app server that only talks to DB and S3):
  MySQL  TCP  3306  sg-rds-id         → Allow MySQL to RDS
  HTTPS  TCP  443   0.0.0.0/0         → Allow HTTPS (for S3, AWS APIs)
```

---

## Security Group Referencing — The Powerful Pattern

Instead of specifying an IP address as the source, you can specify **another Security Group ID**. This means "allow traffic from any resource that has this security group attached."

**Why this is powerful:**

```
Scenario: Web servers need to connect to RDS.

Option 1 (fragile): Allow 10.0.1.0/24 (web server subnet)
  Problem: If you scale web servers or change subnets, you must update the RDS rule

Option 2 (correct): Allow sg-webserver-id (the web server's security group)
  Result: Any EC2 with the web server security group can connect to RDS
          As you scale (add/remove EC2 instances), the rule automatically covers them
```

**Real world setup:**

```
sg-alb:
  Inbound:  HTTP  80   0.0.0.0/0
            HTTPS 443  0.0.0.0/0
  Outbound: All   All  0.0.0.0/0

sg-app-servers:
  Inbound:  HTTP  8080  sg-alb        ← Only ALB can reach app servers
  Outbound: All   All   0.0.0.0/0

sg-rds:
  Inbound:  MySQL 3306  sg-app-servers ← Only app servers can reach RDS
  Outbound: All   All   0.0.0.0/0
```

Traffic flow:
```
Internet → ALB (sg-alb allows 443 from internet)
         → App Server (sg-app-servers allows 8080 from sg-alb)
         → RDS (sg-rds allows 3306 from sg-app-servers)
```

This is the standard 3-tier architecture security pattern.

---

## Security Groups in Practice (CLI)

```bash
# Create a security group
aws ec2 create-security-group \
  --group-name web-server-sg \
  --description "Security group for web servers" \
  --vpc-id vpc-0123456789abcdef0

# Output: GroupId: sg-0123456789abcdef0

# Add inbound rule: allow HTTP from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id sg-0123456789abcdef0 \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Add inbound rule: allow HTTPS from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id sg-0123456789abcdef0 \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Add inbound rule: allow SSH from specific IP only
aws ec2 authorize-security-group-ingress \
  --group-id sg-0123456789abcdef0 \
  --protocol tcp \
  --port 22 \
  --cidr 203.0.113.10/32

# Add inbound rule referencing another security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds-0123456789 \
  --protocol tcp \
  --port 3306 \
  --source-group sg-0123456789abcdef0   ← sg-id, not a CIDR

# Remove an inbound rule
aws ec2 revoke-security-group-ingress \
  --group-id sg-0123456789abcdef0 \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# List rules of a security group
aws ec2 describe-security-groups --group-ids sg-0123456789abcdef0

# Delete a security group
aws ec2 delete-security-group --group-id sg-0123456789abcdef0
```

---

## Important Behaviors to Know

### Multiple Security Groups on One Resource

An EC2 instance can have multiple security groups. Rules from ALL groups are **combined with OR logic** — if ANY group allows the traffic, it's allowed.

```
sg-common: Allow SSH 22 from office-ip
sg-webserver: Allow HTTP 80 from 0.0.0.0/0

EC2 with both groups:
  → SSH from office-ip: Allowed (from sg-common)
  → HTTP from internet: Allowed (from sg-webserver)
  → MySQL from anywhere: Denied (no rule allows it)
```

### Default Security Group

Every VPC has a "default" security group. When you launch a resource without specifying a security group, it gets the default.

Default SG has:
- Inbound: Allow all traffic from resources with the **same default SG**
- Outbound: Allow all traffic to anywhere

This is fine for testing. In production, create dedicated security groups.

### Security Group Limits

- Max 5 security groups per network interface (EC2 has one by default)
- Max 60 inbound + 60 outbound rules per security group
- These limits can be increased via AWS support

---

## Common Mistakes

### Mistake 1: Can't SSH into EC2

```
Error: "Connection timed out" (not "Connection refused")
Checklist:
  □ Security Group inbound: TCP 22 from your IP
  □ EC2 is in a public subnet (has a public IP)
  □ Route table has IGW route
  □ Using the right key pair
```

### Mistake 2: App can't connect to database

```
Checklist:
  □ RDS Security Group inbound: TCP 3306 (or 5432) from app server SG
  □ Both resources are in the same VPC
  □ Using the RDS endpoint (private DNS), not a public IP
```

### Mistake 3: "I don't need outbound rules because SG is stateful"

Half-true. Stateful means **responses** to inbound connections are automatically allowed. But if your EC2 **initiates** a connection outbound (e.g., downloading packages), that's a NEW connection and needs an outbound rule (the default "Allow All" covers this, but if you've restricted outbound, you need to explicitly allow it).

→ Continue to: `03-network-acls.md`
