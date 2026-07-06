# AWS Solutions Architect Associate (SAA-C03) — Complete Roadmap

> **Last updated:** July 4, 2026
> **Exam version:** SAA-C03 (current as of 2026)
> **Prerequisite:** Basic AWS account familiarity (IAM, EC2, S3 basics)
> **Timeline:** 8–12 weeks if you study 1–2 hours/day

---

## What This Exam Actually Tests

The SAA-C03 exam doesn't test memorization — it tests **decision-making**.

Every question gives you a scenario ("A company runs a stateless web app with unpredictable traffic spikes...") and asks which architecture is correct. You're tested on:

| Domain | Weight | What It Means |
|--------|--------|---------------|
| Design Secure Architectures | 30% | IAM, KMS, VPC security, encryption |
| Design Resilient Architectures | 26% | Multi-AZ, failover, backups, decoupling |
| Design High-Performing Architectures | 24% | Scaling, caching, right service selection |
| Design Cost-Optimized Architectures | 20% | Reserved vs Spot, storage tiers, right-sizing |

**Format:**
- 65 questions (scored) + 15 unscored (you don't know which)
- Multiple choice + multiple-select
- 130 minutes
- Passing score: 720/1000
- Cost: $300 USD

---

## The Learning Order (Why This Sequence)

```
Foundation Layer         → IAM, VPC, EC2
    ↓
Storage Layer            → S3, EBS, EFS
    ↓
Database Layer           → RDS, DynamoDB, Aurora, ElastiCache
    ↓
Compute & Scaling        → Auto Scaling, ELB, Lambda, Containers
    ↓
Networking & Delivery    → Route 53, CloudFront, API Gateway
    ↓
Security Deep Dive       → KMS, Secrets Manager, WAF, GuardDuty
    ↓
Integration & Messaging  → SQS, SNS, EventBridge, Kinesis
    ↓
High Availability Design → Multi-AZ patterns, DR strategies
    ↓
Analytics & Migration    → Athena, EMR, DMS, Snow Family
    ↓
Cost & Management        → Cost Explorer, Billing, Organizations
    ↓
Architecture Scenarios   → Practice exams, timed simulations
```

Each layer depends on the one before it. Don't skip to "interesting" services — a Route 53 question about failover requires knowing VPC, EC2, and ELB first.

---

## Phase 0 — Before You Start (Week 0)

### Set Up Your Study Environment

```bash
# 1. Create a free-tier AWS account (if not already done)
#    → aws.amazon.com → Create Account

# 2. Install AWS CLI
brew install awscli           # macOS
aws configure                 # set up credentials

# 3. Bookmark these URLs
#    → AWS Docs:          https://docs.aws.amazon.com
#    → Well-Architected:  https://aws.amazon.com/architecture/well-architected/
#    → Exam Guide:        search "SAA-C03 exam guide PDF" on aws.training
```

### The 5 AWS Well-Architected Pillars

Every exam question maps to one of these. Learn them now — they're the answer framework.

| Pillar | What It Means | Exam Weight |
|--------|---------------|-------------|
| **Operational Excellence** | Run and monitor systems, automate | Low |
| **Security** | Protect data, systems, assets | Very High |
| **Reliability** | Recover from failures, meet demand | Very High |
| **Performance Efficiency** | Use resources efficiently | High |
| **Cost Optimization** | Avoid unnecessary costs | High |

### The AWS Global Infrastructure Mental Model

```
Region (ap-south-1 = Mumbai)
  └── Availability Zone (ap-south-1a)
        └── Data Center(s)
              └── Your EC2/RDS/etc.

Edge Location (CloudFront PoP — 400+ worldwide)
  └── Caches content close to users
```

**Key rule:** AZs in the same Region are connected by low-latency private fiber. Resources across Regions are separate — you must explicitly replicate.

---

## Phase 1 — Foundation Layer (Week 1–2)

### 1.1 IAM (Identity and Access Management)

**Why first:** Every AWS service uses IAM. You can't understand security questions without it.

**Concepts to master:**

```
Users       → A person or application (has credentials)
Groups      → Collection of users (attach policies to groups, not users)
Roles       → An identity with temporary credentials (no permanent keys)
Policies    → JSON document defining what is allowed/denied
```

**The most important IAM concept — Trust vs Permissions:**

```json
// A Role has TWO policy types:
// 1. Trust Policy: WHO can assume this role
{
  "Principal": { "Service": "ec2.amazonaws.com" },  // EC2 can assume this role
  "Action": "sts:AssumeRole"
}

// 2. Permission Policy: WHAT they can do after assuming it
{
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::my-bucket/*"
}
```

**IAM exam patterns:**

| Scenario | Answer |
|----------|--------|
| EC2 needs to read S3 | IAM Role attached to EC2 (NOT access keys on the instance) |
| 3rd party app needs access | IAM Role with cross-account trust |
| Temporary elevated access | IAM Role + STS AssumeRole |
| Block all except one action | Explicit Deny in policy (overrides all Allow) |
| Fine-grained S3 object access | Resource-based policy on the bucket |

**IAM policies evaluation order:**
```
1. Explicit DENY → always wins
2. Explicit ALLOW → grants access
3. Implicit DENY → default if nothing allows
```

**Hands-on:**
- Create a user, group, and policy in the console
- Create an IAM Role for EC2 with S3 read permission
- Attach the role to an EC2 instance and test `aws s3 ls` from inside

---

### 1.2 VPC (Virtual Private Cloud)

**Why second:** Almost every other service lives inside a VPC.

**The mental model:**

```
VPC (your isolated network — e.g., 10.0.0.0/16)
  ├── Public Subnet (10.0.1.0/24) — has route to Internet Gateway
  │     └── EC2 with public IP (accessible from internet)
  │
  ├── Private Subnet (10.0.2.0/24) — no route to Internet Gateway
  │     └── RDS, backend EC2 (not accessible from internet)
  │
  ├── Internet Gateway — your VPC's door to the internet
  ├── NAT Gateway — lets private subnet reach internet (not vice versa)
  └── Route Tables — routing rules per subnet
```

**Security layers in VPC:**

```
Security Group (stateful — attached to EC2/RDS)
  → Inbound: allow port 443 from 0.0.0.0/0
  → Outbound: allow all
  → "Stateful" = if inbound is allowed, return traffic is automatic

Network ACL (stateless — attached to subnet)
  → Rule 100: Allow 443 inbound
  → Rule 200: Allow 1024-65535 inbound (ephemeral ports — required for stateless)
  → "Stateless" = must explicitly allow both directions
```

**Key VPC components to memorize:**

| Component | Purpose | One-liner |
|-----------|---------|-----------|
| Internet Gateway (IGW) | Public internet access | One per VPC |
| NAT Gateway | Private subnet → internet (outbound only) | Deployed in public subnet |
| VPC Peering | Connect two VPCs privately | Not transitive |
| Transit Gateway | Hub-and-spoke for many VPCs | Transitive routing |
| VPC Endpoint (Gateway) | S3/DynamoDB without internet | Free |
| VPC Endpoint (Interface) | Other AWS services without internet | Costs money |
| Bastion Host | SSH jump box into private subnet | EC2 in public subnet |

**VPC exam patterns:**

| Scenario | Answer |
|----------|--------|
| EC2 in private subnet needs to download packages | NAT Gateway in public subnet |
| Two VPCs need to talk privately | VPC Peering |
| 10 VPCs all need to talk to each other | Transit Gateway |
| EC2 needs S3 without internet traffic | VPC Gateway Endpoint for S3 |
| Restrict traffic at subnet level | NACL (stateless) |
| Restrict traffic at instance level | Security Group (stateful) |

**Hands-on:**
- Create a VPC with 2 public + 2 private subnets across 2 AZs
- Add an IGW and NAT Gateway
- Launch EC2 in private subnet, SSH via bastion, confirm can reach internet via NAT

---

### 1.3 EC2 (Elastic Compute Cloud)

**Key concepts:**

**Instance types — just know the families:**
```
T-family   → Burstable (T3, T3a) — dev/test, variable workloads
M-family   → General purpose — balanced CPU/memory
C-family   → Compute-optimized — CPU-heavy (HPC, ML inference)
R-family   → Memory-optimized — in-memory databases, caching
I-family   → Storage-optimized — high IOPS (NoSQL, data warehousing)
G/P-family → GPU — ML training, video encoding
```

**Purchasing options — most exam questions are here:**

| Option | When to Use | Discount vs On-Demand |
|--------|------------|----------------------|
| On-Demand | Unpredictable, short-term | 0% (baseline) |
| Reserved (1yr) | Steady-state, known workload | ~40% |
| Reserved (3yr) | Long-term commitment | ~60% |
| Savings Plan | Flexible Reserved (any instance type) | ~60% |
| Spot | Fault-tolerant, interruptible (batch jobs) | ~70–90% |
| Dedicated Host | Compliance (bring your own license, BYOL) | Most expensive |
| Dedicated Instance | Physical isolation, no BYOL | Expensive |

**EC2 storage options:**
```
EBS (Elastic Block Store)    → Attached disk, persists after stop
  └── gp3 (general SSD)      → most workloads
  └── io2 Block Express       → databases requiring high IOPS
  └── st1 (throughput HDD)   → big data, log processing
  └── sc1 (cold HDD)         → archived data, lowest cost

Instance Store               → Ephemeral disk, data LOST on stop/terminate
                               (but fastest — NVMe directly attached)

EFS (Elastic File System)    → Shared NFS mount — multiple EC2 simultaneously
S3                           → Object storage — not a filesystem
```

**AMI (Amazon Machine Image):** Snapshot of an EC2 instance you can re-launch. Your own AMI = faster boot (pre-baked software).

**Hands-on:**
- Launch EC2 in public subnet with a Security Group
- Attach an EBS volume, format and mount it
- Create a custom AMI from a running instance

---

## Phase 2 — Storage Layer (Week 2–3)

### 2.1 S3 (Simple Storage Service)

S3 is the most-tested service in SAA-C03. Expect 8–12 questions.

**Core concepts:**
```
Bucket    → globally unique name, region-specific
Object    → file up to 5TB; key = full path (e.g., "images/2026/photo.jpg")
Prefix    → simulated folder structure (S3 has no real folders)
```

**Storage classes — cost vs retrieval speed tradeoff:**

| Class | Use Case | Retrieval Time | Cost |
|-------|---------|----------------|------|
| S3 Standard | Frequently accessed | Immediate | Highest |
| S3 Intelligent-Tiering | Unknown access pattern | Immediate | Medium + monitoring fee |
| S3 Standard-IA | Infrequent access | Immediate | Lower (access fee) |
| S3 One Zone-IA | Infrequent, non-critical | Immediate | Lower (single AZ) |
| S3 Glacier Instant | Archives, ms retrieval | Milliseconds | Much lower |
| S3 Glacier Flexible | Archives, hours OK | Minutes–hours | Very low |
| S3 Glacier Deep Archive | Long-term compliance | 12 hours | Lowest |

**S3 security:**
```
Bucket Policy         → Resource-based policy on the bucket (who can access)
ACL (legacy)          → Object-level permissions (avoid — use bucket policies)
Block Public Access   → Account-wide or per-bucket killswitch (default: on)
Pre-signed URLs       → Temporary access to private objects (expires in N seconds)
S3 Object Lock        → WORM (Write Once Read Many) — compliance
```

**S3 encryption:**
```
SSE-S3   → AWS manages keys (default)
SSE-KMS  → Your KMS key (audit trail, key control)
SSE-C    → You provide the key (you manage it)
Client-side → Encrypt before uploading
```

**S3 replication:**
```
CRR (Cross-Region Replication) → Disaster recovery, lower latency
SRR (Same-Region Replication)  → Log aggregation, live replica testing
Requirement: Versioning must be enabled on both buckets
```

**S3 performance:**
- Multipart upload: required >5GB, recommended >100MB
- S3 Transfer Acceleration: uses CloudFront edge locations to speed up uploads
- Prefix parallelization: 3,500 PUT/COPY/POST/DELETE and 5,500 GET per second **per prefix**

**S3 exam patterns:**

| Scenario | Answer |
|----------|--------|
| Objects must not be deleted for 7 years (compliance) | S3 Object Lock + Vault Lock |
| Serve static website from S3 | Enable static website hosting + bucket policy allowing public read |
| Allow only users from specific VPC to access S3 | Bucket policy with `aws:sourceVpc` condition |
| Logs from multiple regions → single bucket for analysis | Cross-Region Replication → destination bucket |
| Cost-optimize: files accessed daily for 30 days, then rarely | S3 Lifecycle → Standard → Standard-IA after 30 days |

---

### 2.2 EBS (Elastic Block Store) Deep Dive

**Volume types (memorize gp3 and io2):**

| Type | IOPS | Throughput | Use Case |
|------|------|-----------|----------|
| gp3 | Up to 16,000 | Up to 1,000 MBps | Default, most workloads |
| gp2 | Up to 16,000 | 250 MBps | Legacy |
| io2 | Up to 256,000 | 4,000 MBps | Databases, SAP, Oracle |
| st1 | Baseline 40 MBps/TB | 500 MBps max | Big data, Kafka logs |
| sc1 | Baseline 12 MBps/TB | 250 MBps max | Cold archives |

**Key rules:**
- One EBS volume → one EC2 (except io1/io2 Multi-Attach, max 16 instances)
- EBS lives in one AZ — to move to another AZ: Snapshot → create volume in new AZ
- Snapshots are incremental and stored in S3 (you don't see them in S3)
- Delete on termination: enabled by default for root volume, disabled for data volumes

---

### 2.3 EFS (Elastic File System)

**When EFS over EBS:**

```
EBS → One EC2, fast block storage (databases, OS disk)
EFS → Many EC2 simultaneously, shared filesystem (content management, home dirs)
```

**EFS performance modes:**
- General Purpose: latency-sensitive (web serving, CMS)
- Max I/O: highly parallel (big data, media processing)

**EFS storage tiers:**
- Standard: frequently accessed
- EFS-IA (Infrequent Access): 92% cheaper; Lifecycle Policy auto-moves files

**EFS vs FSx:**

| Service | Underlying OS | Use Case |
|---------|--------------|----------|
| EFS | Linux NFS | Linux shared storage |
| FSx for Windows | Windows SMB | Windows apps, AD integration |
| FSx for Lustre | HPC filesystem | Machine learning, HPC |
| FSx for NetApp ONTAP | NetApp | Enterprise storage |

---

## Phase 3 — Database Layer (Week 3–4)

### 3.1 RDS (Relational Database Service)

**Supported engines:** MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, Aurora

**Key features:**

```
Multi-AZ        → Standby replica in another AZ (synchronous replication)
                  → Automatic failover if primary fails (2 min)
                  → For AVAILABILITY, not for read performance

Read Replica    → Asynchronous copy for read scaling
                  → Can be in same AZ, different AZ, or different Region
                  → Manually promote to standalone DB if primary fails
                  → For PERFORMANCE (reads), not automatic failover
```

**RDS storage:**
- Auto scaling: set max storage, RDS scales automatically
- gp2 or gp3 for most workloads; io1 for high IOPS

**RDS backup:**
- Automated backups: 0–35 days retention, point-in-time recovery
- DB Snapshots: manual, retained until you delete

**RDS encryption:**
- Enable at creation (can't enable later — must snapshot + restore + encrypt)
- Read Replicas of encrypted DB are encrypted

---

### 3.2 Aurora

Aurora is RDS-compatible but with AWS-optimized architecture. Exam asks it constantly.

**Aurora vs RDS key differences:**

| Feature | RDS MySQL | Aurora MySQL |
|---------|-----------|-------------|
| Storage | EBS per AZ | Distributed across 6 copies in 3 AZs |
| Replicas | 5 read replicas | Up to 15 Aurora Replicas (sub-10ms lag) |
| Failover | 2 minutes | Under 30 seconds |
| Cost | Lower | 20% more than RDS |
| Auto storage | Manual or auto | Automatic (10GB to 128TB) |

**Aurora Serverless:**
- No provisioned capacity — scales from 0 (paused) to N ACUs automatically
- v2: scales in fine-grained increments, production-safe
- Use case: dev/test, intermittent or unpredictable workloads

**Aurora Global Database:**
- Primary Region + up to 5 secondary Regions
- Replication lag < 1 second
- Disaster recovery: promote secondary in < 1 minute
- Use case: globally distributed apps

**Aurora Multi-Master:**
- Multiple write nodes across AZs
- Continuous availability (no failover, all nodes are writable)

---

### 3.3 DynamoDB

AWS's flagship NoSQL — fully managed, serverless key-value and document store.

**Core concepts:**
```
Table      → Collection of items
Item       → A row (up to 400KB)
Attribute  → A column (can be nested)
Primary Key:
  ├── Partition Key only (e.g., UserId)
  └── Partition Key + Sort Key (e.g., UserId + Timestamp)
```

**Capacity modes:**

| Mode | Use Case | Cost Model |
|------|---------|-----------|
| Provisioned | Predictable traffic | Pay for RCU/WCU you reserve |
| On-Demand | Unpredictable traffic | Pay per request |

**DynamoDB features:**

```
DynamoDB Accelerator (DAX)  → In-memory cache, microsecond reads
                              → No application code change needed
                              → Cache for eventually consistent reads

Global Tables               → Multi-region, multi-active (write in any region)
                              → Replication < 1 second

TTL                         → Auto-delete items after expiry timestamp
                              → No cost for TTL deletes

Streams                     → Change data capture (ordered log of changes)
                              → Trigger Lambda on item change
```

**DynamoDB exam patterns:**

| Scenario | Answer |
|----------|--------|
| Sessions for millions of users, fast reads | DynamoDB + DAX |
| Shopping cart (user can access from any region) | DynamoDB Global Tables |
| Delete expired sessions automatically | DynamoDB TTL |
| Trigger workflow on new order | DynamoDB Streams → Lambda |
| Unpredictable traffic spikes | DynamoDB On-Demand |

---

### 3.4 ElastiCache

**Two engines:**

| Engine | Use Case | Protocol |
|--------|---------|---------|
| Redis | Sessions, leaderboards, pub/sub, complex data structures | Redis protocol |
| Memcached | Simple caching, horizontal scaling | Memcached protocol |

**When to use ElastiCache (exam answer pattern):**
- "Database read load is too high" → Add ElastiCache in front of RDS
- "User sessions need to survive EC2 failure" → Store sessions in ElastiCache Redis
- "Leaderboard" → Redis Sorted Sets

**Caching strategies:**
```
Lazy Loading   → Check cache → miss → query DB → store in cache
               → Stale data possible, but cache only has requested data

Write Through  → Write to DB AND cache simultaneously
               → No stale data, but cache has unused items

TTL            → Every item expires after N seconds
               → Balance freshness vs cache hit rate
```

---

### 3.5 Other Databases (Quick Reference)

| Service | Type | When to Use |
|---------|------|------------|
| Redshift | Data Warehouse (SQL) | Analytics over large datasets, BI |
| Neptune | Graph database | Social networks, fraud detection |
| DocumentDB | MongoDB-compatible | JSON documents |
| Keyspaces | Apache Cassandra-compatible | Cassandra migration to AWS |
| Timestream | Time series | IoT, metrics, telemetry |
| QLDB | Ledger (immutable log) | Financial transactions, audit |

---

## Phase 4 — Compute & Scaling (Week 4–5)

### 4.1 Auto Scaling Groups (ASG)

**The core concepts:**
```
Launch Template   → What to launch (AMI, instance type, key pair, SG, user data)
ASG               → How many to launch (min/desired/max), where (subnets)
Scaling Policies  → When to scale
```

**Scaling policy types:**

| Type | Trigger | Use Case |
|------|---------|---------|
| Target Tracking | Keep metric at target (e.g., CPU = 50%) | Simplest, most common |
| Step Scaling | Different steps at different thresholds | Fine-grained control |
| Simple Scaling | Single threshold | Legacy, avoid |
| Scheduled Scaling | At specific times | Known traffic patterns |
| Predictive Scaling | ML-based forecasting | Consistent daily patterns |

**Cooldown period:** After a scaling activity, ASG waits before triggering another. Default 300 seconds. Reduces thrashing.

**Termination policy:** By default, terminates instance in AZ with most instances, then oldest launch template, then closest to billing hour.

**Lifecycle hooks:**
```
Pending:Wait    → Run custom script before instance enters service
Terminating:Wait → Run cleanup before instance is terminated
                   (drain connections, deregister from external systems)
```

---

### 4.2 ELB (Elastic Load Balancer)

Three types — the exam tests which one to pick:

| Type | Protocol | Use Case |
|------|---------|---------|
| Application LB (ALB) | HTTP/HTTPS/WebSocket | Web apps, path/host routing, microservices |
| Network LB (NLB) | TCP/UDP/TLS | Ultra-low latency, static IP, extreme performance |
| Gateway LB (GWLB) | IP (layer 3) | Network appliances (firewalls, deep packet inspection) |
| Classic LB (CLB) | HTTP/HTTPS/TCP | Legacy — don't use |

**ALB features:**
```
Path-based routing     → /api/* → API service, /images/* → image service
Host-based routing     → api.example.com → API ALB target, app.example.com → App target
Header-based routing   → Route based on HTTP headers
Weighted routing       → 90% → v1, 10% → v2 (canary deploys)
Lambda targets         → ALB can invoke Lambda directly
```

**NLB features:**
```
Static IP per AZ       → Required when clients whitelist IPs by firewall
Preserves source IP    → Backend sees real client IP
Lower latency          → ~100µs vs ALB ~400µs
TLS offloading         → NLB handles TLS, sends plaintext to backend
```

**Cross-zone load balancing:**
- ALB: enabled by default
- NLB/GWLB: disabled by default (enable for even distribution)

**Health checks:** ELB marks unhealthy targets and stops sending traffic. Customize path, port, thresholds.

---

### 4.3 Lambda

**Core model:**
```
You upload code → Lambda runs it in response to a trigger
No servers to manage → AWS handles the runtime, scaling, patching
Billed per 100ms of execution + number of requests
```

**Lambda limits (exam critical):**
```
Memory:      128MB – 10GB
CPU:         Proportional to memory (no direct control)
Timeout:     Maximum 15 minutes
Disk (/tmp): Up to 10GB (ephemeral)
Deployment:  50MB zipped / 250MB unzipped
Concurrency: 1,000 per region (can request increase)
```

**Lambda triggers (common exam topics):**
- API Gateway → HTTP request
- S3 → Object created/deleted
- DynamoDB Streams → Item changed
- SQS → Message received
- SNS → Message published
- CloudWatch Events/EventBridge → Scheduled or event-driven
- Kinesis → Stream records

**Lambda concurrency:**
```
Reserved Concurrency  → Guarantee N instances for this function (caps it too)
Provisioned Concurrency → Pre-warm N instances (no cold start)
```

**Cold start:** First invocation or after idle period — takes 100ms–1s to initialize. Use Provisioned Concurrency for latency-sensitive functions.

**Lambda @ Edge:** Run Lambda at CloudFront edge locations for viewer request/response manipulation.

---

### 4.4 Containers on AWS

**ECS (Elastic Container Service) vs EKS (Elastic Kubernetes Service):**

| Feature | ECS | EKS |
|---------|-----|-----|
| Orchestrator | AWS proprietary | Kubernetes |
| Complexity | Simple | Complex |
| Flexibility | Less | More |
| Migration | From scratch | Lift existing k8s |
| Control plane | Free | $0.10/hr per cluster |

**Launch types (applies to both ECS and EKS):**

```
EC2 Launch Type    → You manage EC2 instances in the cluster
Fargate            → Serverless — AWS manages the underlying compute
                     → No EC2 to patch, size, or manage
                     → Pay per vCPU + memory used per second
```

**ECS key concepts:**
```
Task Definition  → Blueprint (Docker image, CPU, memory, env vars, ports)
Task             → A running instance of a task definition
Service          → Keeps N tasks running, integrates with ELB
Cluster          → Group of tasks/services
```

**ECR (Elastic Container Registry):** AWS-managed Docker registry. Stores your container images. Private by default.

---

## Phase 5 — Networking & Content Delivery (Week 5–6)

### 5.1 Route 53

**DNS record types:**
```
A        → Domain → IPv4 (example.com → 1.2.3.4)
AAAA     → Domain → IPv6
CNAME    → Domain → Another domain (www.example.com → example.com)
           Cannot use CNAME at zone apex (root domain)
ALIAS    → Domain → AWS resource (ALB, CloudFront, S3)
           CAN use at zone apex — prefer ALIAS over CNAME for AWS resources
MX       → Mail servers
TXT      → Text records (domain verification, SPF, DKIM)
```

**Routing policies — most exam questions are here:**

| Policy | How It Works | Use Case |
|--------|-------------|---------|
| Simple | One record, one IP | Basic routing |
| Weighted | Split traffic by weight (80/20) | Canary, A/B testing |
| Latency | Route to region with lowest latency | Global apps |
| Failover | Primary active, secondary passive (health check) | Disaster recovery |
| Geolocation | Route based on user's geographic location | Regulatory, localization |
| Geoproximity | Route based on distance with bias | Traffic shifting by region |
| Multi-value | Return multiple IPs (with health checks) | Not a load balancer, but close |

**Health checks:**
- Monitor endpoint, CloudWatch alarm, or other health check
- Failover routing requires health checks on primary
- Combined health check: OR/AND of multiple checks

---

### 5.2 CloudFront

**What it does:** CDN — caches content at Edge Locations near users to reduce latency and origin load.

**Core concepts:**
```
Origin        → Where CloudFront fetches content (S3, ALB, EC2, HTTP server)
Distribution  → Your CloudFront configuration
Edge Location → Cache point worldwide (400+)
TTL           → How long CloudFront caches before re-fetching from origin
Cache Policy  → Controls what goes into the cache key (headers, query strings)
```

**CloudFront + S3:**
```
Origin Access Control (OAC)  → CloudFront gets S3 objects, S3 bucket stays private
                                Users can ONLY access via CloudFront, not directly to S3
```

**CloudFront security:**
```
Signed URLs     → Time-limited access to specific object (single file)
Signed Cookies  → Time-limited access to multiple objects (entire section of site)
Geo Restriction → Block or allow by country
WAF integration → AWS WAF rules on CloudFront (SQL injection, XSS, IP block)
```

**CloudFront exam patterns:**

| Scenario | Answer |
|----------|--------|
| Static website with global users, low latency | S3 + CloudFront |
| Protect S3 from direct access | CloudFront with OAC |
| Serve different content to different countries | CloudFront + Lambda@Edge |
| DDoS protection for global app | CloudFront + AWS Shield |

---

### 5.3 API Gateway

**What it does:** Managed service to create, publish, and manage APIs.

**Types:**
```
REST API       → HTTP APIs, WebSocket, full features
HTTP API       → Lighter, cheaper, lower latency (lacks some REST features)
WebSocket API  → Persistent two-way connections (chat, real-time)
```

**Common architecture:**
```
Client → API Gateway → Lambda (or HTTP backend or ECS)
```

**Key features:**
- Throttling: limits request rate (default 10,000 req/s, burst 5,000)
- Usage plans + API Keys: rate limit per customer
- Caching: cache responses at the API Gateway level (reduces Lambda invocations)
- CORS: configure cross-origin headers
- Authentication: IAM, Lambda authorizer, Cognito

**API Gateway vs ALB:**

| | API Gateway | ALB |
|--|-------------|-----|
| Backend | Lambda, HTTP, AWS services | EC2, ECS, Lambda, IP |
| Features | Auth, throttling, caching, keys | WebSockets, path routing |
| Cost | $3.50/million requests | $0.008/LCU-hour |
| Use when | Serverless, API management needed | Container/EC2 workloads |

---

### 5.4 Direct Connect & VPN

**AWS Site-to-Site VPN:**
```
Your data center → VPN tunnel over internet → AWS VPC
Setup: Virtual Private Gateway (AWS side) + Customer Gateway (your side)
Latency: Variable (goes over public internet)
Time to set up: Minutes to hours
```

**AWS Direct Connect:**
```
Your data center → Dedicated private fiber → AWS
Latency: Consistent, low (bypasses internet)
Bandwidth: 1Gbps or 10Gbps dedicated connections
Time to set up: Weeks to months (physical cabling)
Cost: More expensive but predictable
```

**Exam pattern:** "Company needs consistent low-latency connection to AWS" → Direct Connect. "Company needs quick secure connection to AWS" → VPN.

**Direct Connect + VPN backup:** Use Direct Connect as primary, VPN as failover.

---

## Phase 6 — Security Deep Dive (Week 6–7)

### 6.1 KMS (Key Management Service)

**Core concepts:**
```
CMK (Customer Master Key)  → Your key in KMS
  ├── AWS Managed Keys     → Managed by AWS for a service (e.g., aws/s3)
  └── Customer Managed Keys → You create and manage (full control)

Data Key                   → KMS generates for you to encrypt data
                             KMS never stores data keys — you get them, use them, delete them
Envelope Encryption        → Encrypt data with data key → encrypt data key with CMK
                             (KMS only ever sees the data key, not your data)
```

**When services use KMS:**
- S3: SSE-KMS
- EBS: volume encryption
- RDS: database encryption
- Secrets Manager: automatic encryption
- CloudTrail: log file encryption

**KMS key rotation:**
- AWS Managed: rotated every year automatically
- Customer Managed: enable automatic rotation (annual) or rotate manually

**KMS exam patterns:**

| Scenario | Answer |
|----------|--------|
| S3 objects encrypted, audit log of who decrypted | SSE-KMS (CloudTrail logs KMS calls) |
| Can't share AWS Managed key with another account | Use Customer Managed Key (cross-account CMK sharing) |
| Encrypt data before sending to Lambda | Client-side encryption with KMS data key |

---

### 6.2 Secrets Manager vs SSM Parameter Store

| Feature | Secrets Manager | SSM Parameter Store |
|---------|----------------|---------------------|
| Cost | $0.40/secret/month | Free (Standard) or $0.05/advanced |
| Auto rotation | Yes (built-in Lambda for RDS, Redshift) | No (manual) |
| Cross-account | Yes | Limited |
| Size limit | 64KB | 4KB (Standard) / 8KB (Advanced) |
| Use when | Database passwords, API keys with rotation | Config values, non-sensitive config, cheap storage |

**Exam rule:** If the question says "automatically rotate" → Secrets Manager. For config values and non-secret params → SSM Parameter Store.

---

### 6.3 WAF, Shield, and GuardDuty

**AWS WAF (Web Application Firewall):**
- Filters HTTP/HTTPS requests based on rules
- Protects: CloudFront, ALB, API Gateway, AppSync
- Rules: IP block/allow, geographic blocks, rate limiting, SQL injection, XSS, custom regex

**AWS Shield:**
```
Shield Standard  → Automatic, free, basic DDoS protection (L3/L4)
Shield Advanced  → $3,000/month, protection against large sophisticated attacks
                   → Includes cost protection (if DDoS spikes your bill)
                   → 24/7 DDoS response team access
```

**GuardDuty:**
- Threat detection service (analyzes CloudTrail, VPC Flow Logs, DNS logs)
- Uses ML + threat intelligence
- Detects: compromised instances, unusual API calls, cryptomining, port scanning
- No agents to install — pure SaaS

**Macie:**
- Discovers and classifies sensitive data in S3 (PII, credit cards, SSNs)
- Uses ML to automatically detect sensitive data patterns

**Inspector:**
- Automated security vulnerability scanner for EC2 and container images
- Checks for CVEs, unintended network exposure

**Security Hub:**
- Aggregates findings from GuardDuty, Macie, Inspector, Config, Partner tools
- Single pane of glass for security posture

---

### 6.4 CloudTrail

**What it records:** Every API call made to AWS (who did what, when, from where).

```
Management Events   → Control plane (who created/deleted resources)
Data Events         → Data plane (who accessed S3 objects, Lambda invocations)
Insight Events      → Unusual API activity detection
```

**CloudTrail + S3 + CloudWatch:**
```
CloudTrail → writes logs to S3 (default 90 days in event history)
           → optionally sends to CloudWatch Logs for real-time alerting
           → enable for ALL regions (not just your active region)
```

**CloudTrail exam patterns:**

| Scenario | Answer |
|----------|--------|
| Who deleted the S3 bucket? | CloudTrail |
| Alert when root account is used | CloudTrail → CloudWatch Events → SNS |
| Prove compliance to auditor | CloudTrail logs in S3 (immutable with Object Lock) |

---

## Phase 7 — Integration & Messaging (Week 7–8)

### 7.1 SQS (Simple Queue Service)

**Mental model:** Producer puts messages in queue → Consumer polls and processes → Consumer deletes message.

**Key concepts:**
```
Visibility Timeout   → When consumer picks up message, it's hidden from others
                       If not deleted in time, becomes visible again (reprocessing)
                       Default: 30s, Max: 12 hours

Dead Letter Queue    → Messages that failed processing N times go here
                       Separate queue for failed messages to analyze later

Message Retention    → Default 4 days, max 14 days

Long Polling        → Consumer waits up to 20s for messages (reduces empty responses)
Short Polling       → Returns immediately (even if empty) — wastes API calls
```

**SQS types:**

| Type | Ordering | Throughput | Deduplication |
|------|---------|-----------|--------------|
| Standard | Best-effort | Nearly unlimited | None (may deliver twice) |
| FIFO | Guaranteed order | 300 TPS (3,000 with batching) | Exactly-once |

**SQS exam patterns:**

| Scenario | Answer |
|----------|--------|
| Decouple web tier from processing tier | SQS between web server and workers |
| Order matters (financial transactions) | SQS FIFO |
| Messages failing, need to investigate | SQS Dead Letter Queue |
| Scale EC2 based on queue depth | SQS + CloudWatch → ASG |

---

### 7.2 SNS (Simple Notification Service)

**Mental model:** Publisher sends to Topic → SNS fans out to all Subscribers simultaneously (pub/sub).

**Subscribers:** Email, SMS, HTTP endpoint, Lambda, SQS, mobile push

**SNS + SQS fan-out pattern:**
```
S3 event → SNS Topic → [SQS Queue 1 (thumbnail),
                         SQS Queue 2 (watermark),
                         SQS Queue 3 (metadata indexer)]
```
Why: S3 event notification only goes to ONE destination. Fan-out through SNS sends to multiple SQS queues independently.

**SNS FIFO:** Ordered topic, works only with SQS FIFO subscribers.

---

### 7.3 EventBridge

**What it is:** Serverless event bus — routes events between AWS services, SaaS apps, and your own apps.

```
Event Source           → EC2 state change, S3 put, scheduled cron, partner SaaS
Event Bus              → Default (AWS events), Custom (your app events), Partner (SaaS)
Rules                  → Filter events by pattern, route to target
Target                 → Lambda, SQS, SNS, Step Functions, EC2, Kinesis, API Gateway
```

**CloudWatch Events vs EventBridge:** Same thing. EventBridge is the new name with additional features.

**Schedule:** EventBridge Scheduler can replace cron-triggered Lambda.

---

### 7.4 Kinesis

**For high-volume real-time streaming data (IoT, logs, clickstreams).**

**Four services:**

| Service | Purpose |
|---------|---------|
| Kinesis Data Streams | Ingest and process real-time data (you manage consumers) |
| Kinesis Data Firehose | Load streaming data into S3, Redshift, OpenSearch (managed) |
| Kinesis Data Analytics | SQL or Apache Flink on streaming data |
| Kinesis Video Streams | Stream video from devices |

**Kinesis Data Streams:**
```
Shard      → Unit of capacity (1MB/s in, 2MB/s out)
Partition Key → Determines which shard receives the record
Sequence # → Unique ID per record within a shard
Retention  → Default 24 hours, up to 365 days
```

**SQS vs Kinesis:**

| | SQS | Kinesis Data Streams |
|--|-----|---------------------|
| Use case | Job queue, decoupling | Real-time analytics, multiple consumers |
| Retention | Up to 14 days | Up to 365 days |
| Consumers | One (message deleted after consumption) | Multiple (each reads independently) |
| Ordering | FIFO only with FIFO queue | Per-shard ordering |
| Replay | No | Yes (replay from any point in retention window) |

---

### 7.5 Step Functions

**What it is:** Visual workflow service to coordinate distributed components.

```
State Machine  → The workflow definition (JSON/YAML)
States         → Task, Choice, Parallel, Wait, Succeed, Fail, Pass
```

**Use case:** Multi-step workflows where you need:
- Retry on failure with exponential backoff
- Parallel branches
- Human approval gates
- Error handling and compensation

**Example:** Order processing: Validate → Reserve Inventory → Charge Payment → Send Confirmation → Ship

---

## Phase 8 — High Availability & Disaster Recovery (Week 8)

### 8.1 Multi-AZ Architecture Pattern

**The standard 3-tier HA architecture:**

```
Region: ap-south-1

                     Route 53
                         │
                  ┌──────┴───────┐
                  │   ALB        │
                  └──────┬───────┘
          ┌───────────────┼───────────────┐
          │               │               │
       AZ-a             AZ-b            AZ-c
          │               │               │
    ┌─────┴─────┐   ┌─────┴─────┐   ┌─────┴─────┐
    │  EC2/ECS  │   │  EC2/ECS  │   │  EC2/ECS  │
    │  (Web)    │   │  (Web)    │   │  (Web)    │
    └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
          │               │               │
    ┌─────┴───────────────┴───────────────┴─────┐
    │              Internal ALB                   │
    └─────┬───────────────┬───────────────┬─────┘
          │               │               │
    ┌─────┴─────┐   ┌─────┴─────┐   ┌─────┴─────┐
    │  EC2/ECS  │   │  EC2/ECS  │   │  EC2/ECS  │
    │  (App)    │   │  (App)    │   │  (App)    │
    └───────────┘   └───────────┘   └───────────┘
          │               │
    ┌─────┴─────┐   ┌─────┴─────┐
    │  RDS      │   │  RDS      │
    │ Primary   │   │ Standby   │
    └───────────┘   └───────────┘
```

---

### 8.2 Disaster Recovery Strategies

**Four DR strategies (by cost and RTO/RPO):**

```
Backup & Restore     → Cheapest, longest RTO
                       Backup data to S3/Glacier
                       Restore from scratch when disaster happens
                       RTO: hours, RPO: hours

Pilot Light          → Critical core always running
                       Database replicating to DR region
                       App servers not running — launch from AMI if needed
                       RTO: tens of minutes, RPO: minutes

Warm Standby         → Scaled-down replica of production running in DR
                       Instantly scalable — just increase fleet size
                       RTO: minutes, RPO: seconds

Multi-Site Active-Active → Full production in 2+ regions, load balanced
                           Immediate failover — no RTO
                           Most expensive
```

**Exam rule:** If RTO/RPO requirements are very low → Warm Standby or Active-Active. If cost is the constraint → Backup & Restore.

---

### 8.3 Key HA Services Summary

| Scenario | Service |
|----------|---------|
| Database high availability, automatic failover | RDS Multi-AZ |
| Database read scaling | RDS Read Replicas |
| Database global, multi-region | Aurora Global Database |
| Cache high availability | ElastiCache Redis Cluster Mode |
| App server auto-recovery | EC2 Auto Scaling Group |
| Global DNS failover | Route 53 Failover Routing |
| S3 in two regions | S3 Cross-Region Replication |

---

## Phase 9 — Analytics & Migration (Week 9)

### 9.1 Analytics Services

| Service | What It Does | When to Use |
|---------|-------------|------------|
| Athena | SQL queries directly on S3 (serverless) | Ad-hoc analysis without loading data |
| Glue | ETL (extract, transform, load) + Data Catalog | Data pipelines, schema discovery |
| Redshift | Data warehouse (petabyte-scale SQL) | BI dashboards, complex analytics |
| EMR | Managed Hadoop/Spark | Big data processing, ML at scale |
| QuickSight | Business intelligence / dashboards | Visualizations for non-engineers |
| OpenSearch | Search + log analytics | Log analysis, full-text search |
| Kinesis Data Analytics | Real-time stream analytics | Real-time dashboards, anomaly detection |

**Common exam architecture:**
```
Data pipeline:
S3 (raw data) → Glue ETL → S3 (cleaned) → Athena (query) or Redshift (load)
                                            ↓
                                        QuickSight (visualize)
```

---

### 9.2 Migration Services

**AWS Snow Family (physical data transfer):**

| Device | Capacity | Use Case |
|--------|---------|---------|
| Snowcone | 8TB usable | Edge computing, remote sites |
| Snowball Edge Storage | 80TB usable | Large-scale data migration |
| Snowball Edge Compute | 42TB + compute | Edge processing + transfer |
| Snowmobile | 100PB | Exabyte-scale migration (a truck) |

**Rule:** When moving data > 1 week over the internet → consider Snowball instead.

**Other migration services:**

| Service | Purpose |
|---------|---------|
| DMS (Database Migration Service) | Migrate databases to AWS (homogeneous + heterogeneous) |
| SMS (Server Migration Service) | Migrate on-prem VMs to EC2 |
| Application Migration Service (MGN) | Lift-and-shift servers to AWS |
| DataSync | Online data transfer (NFS/SMB → S3/EFS/FSx) |

---

## Phase 10 — Cost & Management (Week 9–10)

### 10.1 Cost Optimization

**Compute:**
```
On-Demand      → Pay as you go (no commitment)
Savings Plans  → Commit to $/hour spend for 1–3 years (flexible instance types)
Reserved       → Commit to specific instance type/region for 1–3 years
Spot           → Up to 90% off, can be interrupted
```

**Storage:**
- S3 Intelligent-Tiering for uncertain access patterns
- S3 Lifecycle policies to move to cheaper tiers over time
- EBS: delete unused snapshots + volumes; use gp3 instead of gp2 (cheaper + faster)

**Data Transfer:**
- Data IN to AWS: free
- Data OUT from AWS: charged (varies by destination)
- Between AZs within a Region: charged ($0.01/GB each way)
- Between Regions: charged more
- CloudFront → cheaper than EC2 direct for outbound

### 10.2 AWS Organizations

**What it is:** Manage multiple AWS accounts under one organization.

```
Root → Organizational Unit (OU) → AWS Account
                                → AWS Account
       Organizational Unit (OU) → AWS Account
```

**SCP (Service Control Policy):**
- Applied at OU or account level
- Restricts what actions are allowed, regardless of IAM permissions
- Example: Block all Regions except ap-south-1 and us-east-1

**Consolidated billing:** Single payment for all accounts, volume discounts across accounts.

### 10.3 Monitoring and Management

**CloudWatch:**
```
Metrics       → Numeric data (CPU, disk, network) — 1-min or 5-min granularity
Logs          → Text data from apps and services (CloudWatch Logs Agent)
Alarms        → Trigger action when metric crosses threshold (SNS, ASG, EC2 action)
Dashboards    → Visualize metrics
Insights      → Query logs with CloudWatch Logs Insights (like SQL for logs)
```

**CloudWatch vs CloudTrail:**
- CloudWatch: performance and operations (is the system healthy?)
- CloudTrail: governance and audit (who did what?)

**AWS Config:**
- Continuously records configuration changes to AWS resources
- Rules: "Is this S3 bucket public?" (auto-evaluates against your rules)
- Compliance timeline: see when a resource was compliant/non-compliant

**Systems Manager:**
```
Session Manager   → SSH-less access to EC2 (no bastion, no port 22 open)
Parameter Store   → Hierarchical config storage
Patch Manager     → Automated patching for EC2 fleet
Run Command       → Run scripts across EC2 fleet without SSH
Inventory         → Collect software/hardware inventory from EC2
```

---

## Phase 11 — Architecture Patterns & Exam Practice (Week 10–12)

### 11.1 Common Architecture Patterns

**Serverless Web App:**
```
Route 53 → CloudFront → S3 (frontend)
                     ↓
                API Gateway → Lambda → DynamoDB
                                    → ElastiCache
```

**Microservices on Containers:**
```
ALB → ECS (Fargate) services
        ├── Service A → RDS Aurora
        ├── Service B → DynamoDB
        └── Service C → ElastiCache
     SQS for async communication between services
```

**Data Lake:**
```
Kinesis Firehose → S3 (raw)
                    ↓
                Glue ETL → S3 (processed)
                              ↓
                          Athena (ad-hoc queries)
                          Redshift (BI queries)
                          QuickSight (dashboards)
```

**Big Data Processing:**
```
S3 (data) → EMR (Spark/Hadoop) → S3 (output)
                                → Redshift (load)
```

---

### 11.2 How to Read SAA-C03 Questions

**The question structure:**
```
Setup: "A company runs a web application on EC2 instances behind an ALB.
        The application stores user sessions in a local file on each EC2 instance.
        When the ALB routes a user to a different instance, they get logged out."

The question: "What is the MOST cost-effective solution?"

Key words to spot:
  - "most cost-effective" → cheapest option that works
  - "high availability" → Multi-AZ, no single point of failure
  - "highly scalable" → serverless or Auto Scaling
  - "LEAST operational overhead" → managed service (not self-managed)
  - "existing workload" → don't rewrite, lift-and-shift
  - "compliance/regulatory" → encryption, audit, isolation
```

**Answer elimination technique:**
1. Eliminate obviously wrong answers (the exam has 1–2 clearly wrong ones)
2. Eliminate answers that don't address the core problem
3. Between the remaining 2: pick the one that's simpler, managed, or cheaper (based on the question's keyword)

---

### 11.3 Practice Exam Strategy

**Week 10–12 Schedule:**
```
Day 1–3:   Whizlabs Practice Exam #1 (65 questions, timed 130min)
           Review EVERY wrong answer — understand why
Day 4–5:   Review weak areas from exam results
Day 6–7:   Whizlabs Practice Exam #2
...repeat...

Target: Score > 80% consistently before booking the real exam
Real exam: You need 720/1000 (~72%)
```

**Best practice exam resources (in order of quality):**
1. **Tutorials Dojo (Jon Bonso)** — Most realistic, best explanations [tutorialsdojo.com]
2. **Whizlabs** — Volume, covers all topics
3. **AWS Official Practice Exam** — Limited questions but most authentic style
4. **ExamTopics** — Free but verify answers (some are wrong)

**Free official resources:**
- AWS Skill Builder: free digital courses and official practice questions
- AWS FAQs: for each service (S3 FAQ, EC2 FAQ) — exam questions come from here directly

---

## Service Cheat Sheet (Quick Reference)

### "Which service for X?" Answers

| Problem | Answer |
|---------|--------|
| Store user sessions (survive EC2 restart) | ElastiCache Redis or DynamoDB |
| Share files between multiple EC2 | EFS |
| Cheap object storage with rare access | S3 Glacier |
| Fast NoSQL for millions of users | DynamoDB |
| SQL database, no admin overhead | RDS Aurora Serverless |
| Run containers without managing servers | ECS Fargate |
| Run code without any server | Lambda |
| Global low-latency read for database | Aurora Global Database + read replicas |
| Queue for decoupling services | SQS |
| Broadcast same message to many services | SNS |
| Real-time data streaming | Kinesis Data Streams |
| Deliver data stream to S3/Redshift | Kinesis Firehose |
| Serve static website globally | S3 + CloudFront |
| Protect against DDoS | CloudFront + Shield + WAF |
| Route traffic to lowest latency region | Route 53 Latency routing |
| Fail over automatically if site is down | Route 53 Failover routing |
| Connect on-prem to AWS privately | Direct Connect |
| Connect on-prem to AWS quickly | Site-to-Site VPN |
| Big data analytics | EMR |
| Query S3 data with SQL | Athena |
| Move 100TB to AWS (slow internet) | Snowball |
| Encrypt everything, audit key usage | KMS |
| Store DB passwords with auto-rotation | Secrets Manager |
| Detect threats automatically | GuardDuty |
| Find sensitive data in S3 | Macie |
| Scan EC2 for vulnerabilities | Inspector |
| Audit every API call | CloudTrail |
| Monitor app performance | CloudWatch |
| Manage 100 AWS accounts | Organizations + SCP |

---

## Exam Day Checklist

```
Before:
  □ Score > 80% on 3 consecutive practice exams
  □ Review all wrong answers from practice exams
  □ Read the SAA-C03 Exam Guide PDF (AWS official)
  □ Read AWS FAQs for S3, EC2, RDS, Lambda, VPC (top 5 services)

Booking:
  □ Pearson VUE or PSI (online or test center)
  □ Schedule 2 weeks out so you can cancel/reschedule if needed
  □ $300 USD (50% discount on first attempt if you fail anything — check AWS Training discount)

During the exam:
  □ Flag uncertain questions, come back to them
  □ Never leave a question blank (no negative marking)
  □ Eliminate 2 wrong answers first, then pick from the 2 remaining
  □ Read ALL 4 options before answering — the "obvious" first answer is often wrong
  □ "Least operational overhead" always points toward managed services
  □ "Most cost-effective" rarely means the most expensive managed service
```

---

## Recommended Study Resources

| Resource | Type | Cost | Notes |
|----------|------|------|-------|
| **Stephane Maarek (Udemy)** | Video course | ~₹500 on sale | Best overall course |
| **Adrian Cantrill** | Video course | $40/month | Most in-depth, best labs |
| **Tutorials Dojo (Jon Bonso)** | Practice exams | $15 | Most realistic questions |
| **AWS Skill Builder** | Official learning | Free tier available | Official AWS training |
| **AWS Documentation** | Reference | Free | When questions say "according to AWS best practice" |
| **AWS Well-Architected Tool** | Hands-on | Free | Run a review in your AWS account |

**Study flow recommendation:**
```
Week 1–8:   Watch video course (Maarek or Cantrill) + hands-on labs in AWS Console
Week 9:     First practice exam + gap analysis
Week 10–11: Targeted review of weak areas + 2 more practice exams
Week 12:    Final practice exam (must be > 80%) → Book + take the exam
```

---

## After SAA-C03 — What's Next?

```
SAA-C03 Associate (this exam)
    ↓
SAP-C02 Professional (harder, architect-level design)
    OR
DevOps Engineer Professional (DOP-C02) — aligns with your DevOps background
    ↓
Specialty Certifications:
  ├── Security Specialty (SCS-C02) — IAM, KMS, compliance deep dive
  ├── Database Specialty (DBS-C01)
  ├── Machine Learning Specialty (MLS-C01)
  └── Advanced Networking Specialty (ANS-C01)
```

Given your DevOps background, **DevOps Professional (DOP-C02)** after SAA is a natural path — it covers CodePipeline, CodeDeploy, ECS/EKS CI/CD, IaC at depth.
