# VPC — 03: Network ACLs

> **Last updated:** July 5, 2026
> **The stateless subnet-level firewall — and why ephemeral ports confuse everyone.**

---

## What Is a Network ACL?

A **Network ACL (NACL)** is a firewall that controls traffic at the **subnet level**, not the resource level.

```
VPC
  └── Subnet (has a NACL attached)
        └── EC2 (has a Security Group attached)
```

Traffic entering a subnet passes through the NACL first, then hits the Security Group.

---

## NACL vs Security Group — The Key Differences

| Feature | Security Group | NACL |
|---------|---------------|------|
| Attached to | Individual resource (EC2, RDS) | Subnet |
| Stateful/Stateless | **Stateful** — return traffic automatic | **Stateless** — must allow both directions |
| Rules | Allow only | Allow AND Deny |
| Rule evaluation | All rules evaluated, combined | Rules evaluated in order (lowest number first), first match wins |
| Default behavior | Block all inbound | Allow all inbound + outbound |

---

## Stateless — Why It Matters

This is the #1 confusion point with NACLs.

Because NACLs are **stateless**, they don't remember that a connection was established. Every packet is evaluated independently — both the request AND the response.

**Example: User requests your website**

Request (inbound):
```
User's browser sends: TCP packet to EC2 port 443 (HTTPS)
NACL inbound rules must ALLOW: TCP port 443 from 0.0.0.0/0 ✅
```

Response (outbound):
```
EC2 sends response: TCP packet from EC2 to user's browser
The user's browser picked a random ephemeral port (e.g., 54321) for this connection
NACL outbound rules must ALLOW: TCP port 54321 outbound
```

But you don't know which ephemeral port the user picked! It could be anything in the range **1024–65535**.

**So your NACL outbound rule must allow the entire ephemeral port range:**

```
Outbound rule: Allow TCP 1024-65535 to 0.0.0.0/0
```

A Security Group doesn't need this — it's stateful and automatically allows the response.

---

## NACL Rule Evaluation — Rule Numbers

NACL rules are evaluated **in ascending order by rule number**. The first matching rule wins.

```
NACL Inbound Rules:
Rule#  Protocol  Port    Source        Action
100    TCP        443     0.0.0.0/0    ALLOW     ← evaluated first
200    TCP        80      0.0.0.0/0    ALLOW
300    TCP        22      10.0.0.0/8   ALLOW
*      All        All     0.0.0.0/0    DENY      ← catch-all deny (default)
```

The `*` rule (no number) is the default: deny everything not explicitly allowed. You can't modify this rule.

**Blocking a specific IP:**

```
Rule#  Protocol  Port    Source          Action
50     TCP        All     203.0.113.100/32  DENY   ← DENY this IP first (rule 50 < 100)
100    TCP        80      0.0.0.0/0       ALLOW
*      All        All     0.0.0.0/0       DENY
```

Rule 50 blocks the specific IP before rule 100 can allow it. Rule numbers matter.

---

## Default NACL vs Custom NACL

**Default NACL** (created with every VPC):
- Inbound: Allow all traffic
- Outbound: Allow all traffic
- All subnets are associated with the default NACL unless you assign a custom one

**Custom NACL** (when you create a new one):
- Inbound: Deny all (only the `*` DENY rule)
- Outbound: Deny all (only the `*` DENY rule)
- You must add explicit Allow rules

---

## A Complete NACL for a Public Subnet (Web Server)

```
Public Subnet NACL — Inbound Rules:
Rule#  Type       Protocol  Port         Source            Action
100    HTTP       TCP        80           0.0.0.0/0         ALLOW
110    HTTPS      TCP        443          0.0.0.0/0         ALLOW
120    SSH        TCP        22           YOUR_OFFICE_IP/32 ALLOW
130    Custom     TCP        1024-65535   0.0.0.0/0         ALLOW  ← RETURN traffic from internet
*      All        All        All          0.0.0.0/0         DENY

Public Subnet NACL — Outbound Rules:
Rule#  Type       Protocol  Port         Destination       Action
100    HTTP       TCP        80           0.0.0.0/0         ALLOW
110    HTTPS      TCP        443          0.0.0.0/0         ALLOW
120    Custom     TCP        1024-65535   0.0.0.0/0         ALLOW  ← RESPONSE traffic to browsers
*      All        All        All          0.0.0.0/0         DENY
```

Why rule 130 inbound (1024-65535)?
Your EC2 initiates outbound connections (e.g., downloading updates). The internet server responds on your EC2's ephemeral port. That RESPONSE traffic is INBOUND to the subnet, so you must allow it inbound.

Why rule 120 outbound (1024-65535)?
Users connect from their browsers using ephemeral source ports (e.g., 52341). Your EC2 responds TO those ports. That response is OUTBOUND from the subnet, so you must allow it outbound.

---

## NACL for a Private Subnet (App Tier)

```
Private Subnet NACL — Inbound Rules:
Rule#  Protocol  Port         Source                Action
100    TCP        8080         10.0.1.0/24 (pub sub) ALLOW  ← App port from public subnet (or ALB)
110    TCP        1024-65535   10.0.1.0/24           ALLOW  ← Return traffic from public subnet
*      All        All          0.0.0.0/0             DENY

Private Subnet NACL — Outbound Rules:
Rule#  Protocol  Port         Destination           Action
100    TCP        443          0.0.0.0/0             ALLOW  ← HTTPS out (via NAT for internet)
110    TCP        3306         10.0.4.0/24 (db sub)  ALLOW  ← MySQL to DB subnet
120    TCP        1024-65535   10.0.1.0/24           ALLOW  ← Responses back to public subnet
*      All        All          0.0.0.0/0             DENY
```

---

## CLI: Working with NACLs

```bash
# Create a NACL
aws ec2 create-network-acl --vpc-id vpc-0123456789abcdef0
# Returns: NetworkAclId: acl-0123456789abcdef0

# Add inbound rule (allow HTTPS)
aws ec2 create-network-acl-entry \
  --network-acl-id acl-0123456789abcdef0 \
  --ingress \
  --rule-number 100 \
  --protocol tcp \
  --port-range From=443,To=443 \
  --cidr-block 0.0.0.0/0 \
  --rule-action allow

# Add outbound rule (allow ephemeral ports)
aws ec2 create-network-acl-entry \
  --network-acl-id acl-0123456789abcdef0 \
  --egress \
  --rule-number 120 \
  --protocol tcp \
  --port-range From=1024,To=65535 \
  --cidr-block 0.0.0.0/0 \
  --rule-action allow

# Associate NACL with a subnet
aws ec2 replace-network-acl-association \
  --association-id aclassoc-xxxx \
  --network-acl-id acl-0123456789abcdef0

# Describe a NACL
aws ec2 describe-network-acls --network-acl-ids acl-0123456789abcdef0
```

---

## When to Use NACLs vs Security Groups

In practice:
- **Security Groups are sufficient for 90% of use cases.** Use them for all resource-level control.
- **Use NACLs when you need to DENY a specific IP.** Security groups can't deny — they can only allow. NACLs can explicitly deny.

Common NACL use case:
```
Scenario: DDoS attack from IP 203.0.113.100
Action: Add a NACL rule to DENY all traffic from that IP
        Security Group can't do this (no deny rules)
```

**Exam rule:** "Block a specific IP address" → always NACL (not Security Group).

---

## Summary: The Two-Layer Defense

```
Traffic from internet → enters subnet
    ↓
NACL checks (subnet-level, stateless)
    Allow or Deny based on rules
    ↓
Security Group checks (resource-level, stateful)
    Allow or implicit Deny
    ↓
Your EC2/RDS/Lambda
```

Both layers must allow the traffic for it to reach the resource.

→ Continue to: `04-nat-gateway.md`
