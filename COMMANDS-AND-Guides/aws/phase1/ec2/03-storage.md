# EC2 — 03: Storage

> **Last updated:** July 5, 2026
> **EBS, Instance Store, EFS — what they are, when to use each, and how they work.**

---

## The Three Storage Options for EC2

```
EBS (Elastic Block Store)
  → Attached disk, like a USB drive plugged into your EC2
  → Data persists when you stop/start or even detach
  → One EC2 at a time (mostly)
  → Most common choice for root volumes and data disks

Instance Store
  → Physical disk directly attached to the host server
  → Extremely fast (NVMe)
  → Data is LOST when you stop, terminate, or if the instance fails
  → Ephemeral — not suitable for anything you can't afford to lose

EFS (Elastic File System)
  → Network file system, shared across multiple EC2 instances
  → Like a shared NFS mount
  → Automatically scales, multiple EC2 can read/write simultaneously
```

---

## EBS (Elastic Block Store)

### The Key Concepts

```
Volume  → The disk itself. Created independently of any EC2 instance.
          Exists in one specific AZ.

Attach  → Connect a volume to an EC2 instance (like plugging in a USB drive)
          EC2 and EBS must be in the SAME AZ.

Detach  → Disconnect the volume from EC2 (data still on the volume)

Delete  → Remove the volume permanently (data gone)
```

**Root volume:** The EBS volume with the OS. When you launch EC2, AWS creates one automatically. By default, it's deleted when the instance terminates. You can change this.

**Additional volumes:** You can attach multiple EBS volumes to one EC2. Use these for data (separate from OS).

### EBS Volume Types

| Type | Kind | Max IOPS | Max Throughput | Use Case |
|------|------|----------|----------------|---------|
| `gp3` | SSD | 16,000 | 1,000 MBps | Default: most workloads |
| `gp2` | SSD | 16,000 | 250 MBps | Legacy (use gp3 instead) |
| `io2 Block Express` | SSD | 256,000 | 4,000 MBps | SAP HANA, Oracle, large DBs |
| `io1` | SSD | 64,000 | 1,000 MBps | High-perf databases |
| `st1` | HDD | 500 IOPS | 500 MBps | Big data, Kafka logs, throughput |
| `sc1` | HDD | 250 IOPS | 250 MBps | Cold storage, infrequent access |

**gp3 vs gp2:**
- `gp3`: You configure IOPS and throughput independently. More control, **20% cheaper** than gp2. Use gp3.
- `gp2`: IOPS scales with volume size (3 IOPS/GB). Legacy, less flexible.

**gp3 vs io2:**
- `gp3`: Max 16,000 IOPS. Sufficient for most workloads.
- `io2`: Needed when you require >16,000 IOPS (SAP HANA, high-performance Oracle). Expensive.

### EBS Sizing

```bash
# EBS volumes can be resized without downtime (increase only, not decrease):
aws ec2 modify-volume \
  --volume-id vol-0123456789abcdef0 \
  --size 100          # increase from 50GB to 100GB

# After resize, you must extend the filesystem on the instance:
# For Linux:
sudo growpart /dev/xvda 1    # extend partition
sudo resize2fs /dev/xvda1    # ext4
# or for XFS:
sudo xfs_growfs /             # XFS
```

### EBS Snapshots

A **snapshot** is a point-in-time backup of an EBS volume. Stored in S3 (but you can't see them in S3 — managed by AWS).

```
EBS Volume → Snapshot
```

Properties:
- **Incremental:** Only changed data since last snapshot is stored (saves cost)
- **Cross-AZ/Region copy:** You can copy a snapshot to any region → create a volume from it in that region. This is how you move EBS across AZs or regions.
- **Shareable:** You can share snapshots with other AWS accounts

```bash
# Create a snapshot
aws ec2 create-snapshot \
  --volume-id vol-0123456789abcdef0 \
  --description "Backup before upgrade"

# List snapshots
aws ec2 describe-snapshots --owner-ids self

# Create volume from snapshot (in a different AZ)
aws ec2 create-volume \
  --snapshot-id snap-0123456789abcdef0 \
  --availability-zone ap-south-1b \
  --volume-type gp3

# Copy snapshot to another region
aws ec2 copy-snapshot \
  --source-snapshot-id snap-0123456789abcdef0 \
  --source-region ap-south-1 \
  --destination-region us-east-1 \
  --description "DR copy"

# Delete a snapshot
aws ec2 delete-snapshot --snapshot-id snap-0123456789abcdef0
```

### EBS Encryption

```
Encrypted EBS volume:
  → Data at rest: encrypted (AES-256)
  → Data in transit (EC2 ↔ EBS): encrypted
  → Snapshots of encrypted volumes: automatically encrypted
  → Volumes from encrypted snapshots: automatically encrypted

Key: AWS managed key (free) or your KMS key (for audit trail)
```

**Enabling encryption:**
- At volume creation: check "Encryption" and select a key
- You CANNOT encrypt an existing unencrypted volume in-place

To encrypt an existing unencrypted volume:
```
1. Snapshot the unencrypted volume
2. Copy the snapshot with encryption enabled
3. Create a new encrypted volume from the encrypted snapshot
4. Detach old volume, attach new volume
5. Delete old unencrypted volume and snapshot
```

### Multi-Attach (io1/io2 Only)

Normally, one EBS volume can be attached to ONE EC2 instance.

With Multi-Attach (only on io1/io2 volumes), you can attach one volume to up to 16 EC2 instances in the same AZ.

Use case: Clustered databases that need shared storage (Oracle RAC, etc.). You must manage filesystem locking in your application.

---

## Instance Store

The EC2 host machine has physical SSDs (NVMe) that can be attached directly to your instance as "instance store."

**Properties:**
- Fastest possible storage — directly attached, no network (sub-millisecond latency)
- **Ephemeral — data is lost when:**
  - Instance is stopped (even temporarily)
  - Instance is terminated
  - Hardware fails (the physical server dies)
- **Data survives:** reboots (OS restart without stopping)
- Available only on specific instance types (I3, D3, H1, X1, etc.)
- No extra cost — included in the instance price

**When to use:**
```
✅ Temporary data (sort buffers, swap space)
✅ Data replicated across multiple instances (Cassandra, HDFS, Kafka replicated topics)
✅ Scratch space for batch processing
✅ Cache that can be rebuilt from another source

❌ Anything you can't afford to lose
❌ Databases that need durability
❌ Application logs
```

---

## EFS (Elastic File System)

**EFS is a managed NFS (Network File System)** — you mount it on EC2 like a regular Linux directory, but it can be mounted on many EC2 instances simultaneously.

```
EC2-1 (AZ-a) ─────┐
EC2-2 (AZ-a) ─────┤── EFS ── shared filesystem
EC2-3 (AZ-b) ─────┤
EC2-4 (AZ-b) ─────┘

All EC2 instances read/write to the same filesystem simultaneously
```

**EBS vs EFS:**

| | EBS | EFS |
|--|-----|-----|
| OS | Linux + Windows | Linux only (NFSv4) |
| Attach to | One EC2 (or 16 with Multi-Attach) | Many EC2 simultaneously |
| Protocol | Block device | NFS |
| Performance | Up to 256K IOPS (io2) | Up to 500K+ IOPS (Max I/O) |
| Storage | Fixed size (you provision) | Grows automatically |
| Cost | $0.08-0.10/GB-month | $0.30/GB-month (3× more expensive) |
| Use case | OS disk, databases | Shared content, home directories, CMS |

**EFS Performance Modes:**
- `General Purpose`: Low latency (<1ms). Default. Use for web serving, content management.
- `Max I/O`: Higher latency but massively parallel. Use for big data, media processing.

**EFS Storage Tiers (Lifecycle):**
```
Standard Tier          → Frequently accessed (full price)
Infrequent Access (IA) → 92% cheaper, $0.025/GB-month
One Zone IA            → Cheaper still, single AZ (no multi-AZ durability)
```

Use Lifecycle Policy to automatically move files not accessed in N days to IA tier.

```bash
# Create an EFS filesystem
aws efs create-file-system \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --tags Key=Name,Value=vault-efs

# Create mount targets in each subnet (one per AZ)
aws efs create-mount-target \
  --file-system-id fs-0123456789abcdef0 \
  --subnet-id subnet-private-az-a \
  --security-groups sg-efs

# Mount on EC2 (install amazon-efs-utils first)
sudo apt-get install amazon-efs-utils
sudo mount -t efs fs-0123456789abcdef0:/ /mnt/efs

# Or mount with encryption in transit:
sudo mount -t efs -o tls fs-0123456789abcdef0:/ /mnt/efs
```

**EFS Security Group:** You need to create a security group for EFS that allows NFS (TCP 2049) from your EC2 security groups.

---

## Storage Decision Summary

```
I need...                                              Use
──────────────────────────────────────────────────────────
Root disk for EC2 (OS)                               → EBS gp3
Data disk for one EC2 (app data, logs)               → EBS gp3
High IOPS database (PostgreSQL, MySQL)               → EBS gp3 or io2
Fastest possible, can afford data loss               → Instance Store
Share files across multiple EC2 (CMS, shared uploads)→ EFS
Linux home directories for multiple users            → EFS
Large files rarely accessed, need to share           → S3
```

→ Continue to: `04-ami-and-launch.md`
