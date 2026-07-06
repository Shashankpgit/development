# EC2 — 05: EC2 Networking

> **Last updated:** July 5, 2026
> **ENI, public vs private IPs, Elastic IPs, placement groups, and metadata service.**

---

## ENI — Elastic Network Interface

An **ENI (Elastic Network Interface)** is a virtual network card. Every EC2 instance has at least one — the primary ENI (eth0).

An ENI has:
- One primary private IP address (assigned from subnet CIDR)
- Optionally one or more secondary private IP addresses
- Optionally one public IP address (if in public subnet)
- Optionally one Elastic IP address per private IP
- One or more security groups
- A MAC address

```
EC2 Instance
  └── eth0 (primary ENI)
        ├── Private IP: 10.0.1.50
        ├── Public IP: 52.66.100.50  (if in public subnet)
        └── Security Groups: [sg-web]
```

### Why ENIs Matter

You can **attach additional ENIs** to an EC2 instance:

```
EC2 Instance
  ├── eth0 (primary ENI) → 10.0.1.50 (public subnet)
  └── eth1 (secondary ENI) → 10.0.2.50 (private subnet)
```

Use cases:
- Dual-homed instances (connected to two subnets)
- Network appliances (firewall, NAT instances)
- Moving a network interface between instances (preserves private IP and MAC address)

### Moving an ENI

You can detach a secondary ENI from one instance and attach it to another. The private IP and MAC address move with it.

Use case: Your app license is tied to a MAC address → create a dedicated ENI → always attach that ENI to whichever instance runs the licensed app.

```bash
# Detach an ENI
aws ec2 detach-network-interface \
  --attachment-id eni-attach-0123456789abcdef0

# Attach to another instance
aws ec2 attach-network-interface \
  --network-interface-id eni-0123456789abcdef0 \
  --instance-id i-new-instance \
  --device-index 1
```

---

## IP Addresses Deep Dive

### Private IP

- Assigned from the subnet CIDR when the instance launches
- Stays the same for the lifetime of the instance
- Used for all internal VPC communication
- Used when calling other AWS services (RDS, S3 endpoint, etc.)

### Public IP

- Automatically assigned when launching in a public subnet (if "auto-assign public IP" is enabled)
- **Changes every time you stop and start the instance**
- Not charged (included in EC2 price while running)
- When you stop the instance, the public IP is released back to AWS's pool

### Elastic IP

- A static public IP that YOU own and control
- Doesn't change when you stop/start
- Can be moved between instances (failover: move EIP from failed instance to standby)
- **Charged if NOT associated with a running instance** (~$0.005/hr)

```bash
# Get an EIP
aws ec2 allocate-address --domain vpc

# Associate with an instance
aws ec2 associate-address \
  --instance-id i-1234567890abcdef0 \
  --allocation-id eipalloc-xxxx

# Move EIP to another instance (failover)
aws ec2 associate-address \
  --instance-id i-new-instance \
  --allocation-id eipalloc-xxxx \
  --allow-reassociation    # disassociates from current instance first

# Disassociate
aws ec2 disassociate-address --association-id eipassoc-xxxx

# Release (give up the IP entirely)
aws ec2 release-address --allocation-id eipalloc-xxxx
```

### IPv6

AWS also supports IPv6 for VPCs. IPv6 addresses are globally unique — no NAT needed. But most workloads don't need it today. Skip for SAA-C03 unless specifically asked.

---

## EC2 Instance Metadata Service (IMDS)

Every EC2 instance can access a special URL to get information about itself:

```
http://169.254.169.254/latest/meta-data/
```

This IP (`169.254.169.254`) is a link-local address — only reachable from within the instance itself. It's not a real server — it's answered by the EC2 hypervisor.

**What you can get from the metadata service:**

```bash
# From inside an EC2 instance:

# Your instance ID
curl http://169.254.169.254/latest/meta-data/instance-id
# i-1234567890abcdef0

# Your private IP
curl http://169.254.169.254/latest/meta-data/local-ipv4
# 10.0.1.50

# Your public IP
curl http://169.254.169.254/latest/meta-data/public-ipv4
# 52.66.100.50

# Your instance type
curl http://169.254.169.254/latest/meta-data/instance-type
# t3.medium

# Your availability zone
curl http://169.254.169.254/latest/meta-data/placement/availability-zone
# ap-south-1a

# Your IAM role credentials (temporary)
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
# vault-api-role
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/vault-api-role
# Returns: AccessKeyId, SecretAccessKey, Token, Expiration

# Your user data (the script you passed at launch)
curl http://169.254.169.254/latest/user-data
```

The AWS SDKs use the IAM credentials endpoint automatically — that's how EC2 "knows" to use the role.

### IMDSv2 (Secure Version)

IMDSv1 is a simple GET request — vulnerable to SSRF attacks (if your app is hacked, attacker can fetch credentials from metadata).

IMDSv2 requires a token:

```bash
# Step 1: Get a token (valid for 6 hours)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Step 2: Use the token for all metadata requests
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

**Best practice:** Launch all instances with IMDSv2 required:

```bash
aws ec2 run-instances \
  --metadata-options HttpTokens=required,HttpPutResponseHopLimit=1 \
  ...
```

Or enforce it account-wide:
```bash
aws ec2 modify-instance-metadata-defaults \
  --http-tokens required \
  --region ap-south-1
```

---

## Placement Groups

A **Placement Group** controls where your instances are physically placed within AWS.

### Cluster Placement Group

```
All instances → on the same physical rack (or adjacent racks)
Low latency  → ~10Gbps network between instances (vs 1-5Gbps normally)
Risk         → If the rack fails, ALL instances fail
Use when     → HPC, Hadoop, distributed computing where latency matters
```

### Spread Placement Group

```
Each instance → on a DIFFERENT physical rack
High availability → one rack failure affects only one instance
Max 7 instances per AZ (7 racks per AZ limit)
Use when → Small critical apps that need maximum HA per AZ
```

### Partition Placement Group

```
Instances divided into groups (partitions)
Each partition → on different racks
Multiple instances per partition
Hadoop/Cassandra/Kafka know which partition they're in
Use when → Large distributed workloads (Cassandra, HDFS, HBase)
```

```bash
# Create a placement group
aws ec2 create-placement-group \
  --group-name vault-cluster \
  --strategy cluster   # or spread or partition

# Launch instance in the placement group
aws ec2 run-instances \
  --placement GroupName=vault-cluster \
  ...
```

---

## Networking Quick Reference

```bash
# Get all IPs for an instance
aws ec2 describe-instances \
  --instance-ids i-1234567890abcdef0 \
  --query 'Reservations[].Instances[].{
    PrivateIP: PrivateIpAddress,
    PublicIP: PublicIpAddress,
    InstanceId: InstanceId,
    State: State.Name
  }'

# List ENIs attached to an instance
aws ec2 describe-instances \
  --instance-ids i-1234567890abcdef0 \
  --query 'Reservations[].Instances[].NetworkInterfaces[*].{
    ID: NetworkInterfaceId,
    IP: PrivateIpAddress,
    SubnetId: SubnetId
  }'

# Describe all Elastic IPs
aws ec2 describe-addresses --query 'Addresses[*].{IP:PublicIp,ID:AllocationId,Instance:InstanceId}'
```

→ Continue to: `06-ec2-in-practice.md`
