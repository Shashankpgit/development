# EC2 — 01: Instance Types

> **Last updated:** July 5, 2026
> **How to read instance type names, understand the families, and pick the right one.**

---

## Reading an Instance Type Name

```
  t   3   .   micro
  │   │       │
  │   │       └── Size (nano, micro, small, medium, large, xlarge, 2xlarge, ...)
  │   │
  │   └── Generation (higher = newer, better price/performance)
  │
  └── Family (what it's optimized for)
```

Examples:
```
t3.micro      → Burstable, gen 3, micro size (2 vCPU, 1 GB RAM)
m5.xlarge     → General purpose, gen 5, xlarge (4 vCPU, 16 GB RAM)
c6g.2xlarge   → Compute optimized, gen 6, ARM (Graviton), 2xlarge (8 vCPU, 16 GB RAM)
r6i.large     → Memory optimized, gen 6, Intel, large (2 vCPU, 16 GB RAM)
i3en.xlarge   → Storage optimized, gen 3 enhanced, xlarge (4 vCPU, 32 GB RAM)
p3.2xlarge    → GPU accelerated (NVIDIA V100), 2xlarge (8 vCPU, 61 GB RAM)
```

---

## Instance Families — The Main Ones

### T Family — Burstable (dev/test, light workloads)

```
T3, T3a, T4g

Behavior:
  - Base CPU performance (e.g., 20% of vCPU)
  - Earns CPU credits over time when below baseline
  - Can "burst" to 100% CPU using accumulated credits
  - When credits run out → performance drops to baseline

CPU credit analogy:
  Think of a rechargeable battery.
  Idle time → charges the battery
  CPU spike  → drains the battery
  Battery empty → performance throttled

Use when: Development, low-traffic websites, test environments
Avoid when: Production workloads with consistent CPU needs
```

```
t3.nano   → 2 vCPU, 0.5 GB RAM  → ~$0.005/hr
t3.micro  → 2 vCPU, 1 GB RAM    → ~$0.010/hr  (free tier eligible)
t3.small  → 2 vCPU, 2 GB RAM    → ~$0.021/hr
t3.medium → 2 vCPU, 4 GB RAM    → ~$0.042/hr
t3.large  → 2 vCPU, 8 GB RAM    → ~$0.083/hr
```

### M Family — General Purpose (balanced, most workloads)

```
M5, M5a, M6i, M6g, M7i

CPU:Memory ratio = 1:4 (1 vCPU per 4 GB RAM)

Use when: Web servers, app servers, small databases, development environments
          that need consistent (not burstable) performance
```

```
m5.large   → 2 vCPU, 8 GB RAM   → ~$0.096/hr
m5.xlarge  → 4 vCPU, 16 GB RAM  → ~$0.192/hr
m5.2xlarge → 8 vCPU, 32 GB RAM  → ~$0.384/hr
m5.4xlarge → 16 vCPU, 64 GB RAM → ~$0.768/hr
```

### C Family — Compute Optimized (CPU-heavy)

```
C5, C6g, C6i, C7g

CPU:Memory ratio = 1:2 (more vCPU per GB RAM than M)

Use when: Web servers with high request rates, batch processing,
          video encoding, machine learning inference, HPC
Avoid when: Memory-heavy workloads (not enough RAM per vCPU)
```

```
c5.large   → 2 vCPU, 4 GB RAM   → ~$0.085/hr (cheaper than M but less RAM)
c5.xlarge  → 4 vCPU, 8 GB RAM   → ~$0.170/hr
c5.2xlarge → 8 vCPU, 16 GB RAM  → ~$0.340/hr
```

### R Family — Memory Optimized (RAM-heavy)

```
R5, R6i, R6g, R7i

CPU:Memory ratio = 1:8 (lots of RAM per vCPU)

Use when: In-memory databases (Redis, SAP HANA), large in-memory caches,
          big data analytics loaded into RAM, real-time big data processing
```

```
r5.large   → 2 vCPU, 16 GB RAM  → ~$0.126/hr
r5.xlarge  → 4 vCPU, 32 GB RAM  → ~$0.252/hr
r5.2xlarge → 8 vCPU, 64 GB RAM  → ~$0.504/hr
```

### I Family — Storage Optimized (high IOPS NVMe)

```
I3, I3en, I4i

NVMe SSD directly attached (instance store)
Extremely high IOPS and throughput

Use when: High-performance NoSQL databases (Cassandra, MongoDB),
          data warehousing, ElasticSearch, Kafka
Note: Instance store — data is lost on stop/terminate
```

### P/G Family — GPU (machine learning, graphics)

```
P3, P4, G4dn, G5

NVIDIA GPUs for parallel computing

Use when: ML training, deep learning inference, video rendering
```

### X/U Family — Extreme Memory

```
X1e, x2gd, u-

Hundreds of GB to 24TB RAM

Use when: SAP HANA, in-memory databases at massive scale
```

---

## The Processor Letter Suffix

```
No suffix  → Intel Xeon (most common)
a suffix   → AMD EPYC (e.g., m5a, r5a) — ~10% cheaper than Intel
g suffix   → AWS Graviton (ARM, e.g., m6g, c6g) — ~20% cheaper, often better perf/$ 
i suffix   → Latest Intel generation (e.g., m6i, c6i)
n suffix   → High network bandwidth
d suffix   → NVMe instance store attached (local SSD)
```

**Graviton (g suffix):** AWS's custom ARM processor. Cheaper and often faster than Intel/AMD equivalent. Compatible with most Linux workloads. Not compatible with Windows or software requiring x86 instruction set.

---

## Choosing an Instance Type — Decision Flow

```
What does your workload look like?
  │
  ├── Dev/test or light traffic?
  │   → T3/T4g (burstable, cheap)
  │
  ├── Steady production web/app server?
  │   → M5/M6i/M6g (balanced)
  │
  ├── High CPU, low memory? (batch, encoding, HPC)
  │   → C5/C6g (compute optimized)
  │
  ├── Lots of RAM? (Redis, in-memory DB, big data)
  │   → R5/R6i (memory optimized)
  │
  ├── Massive IOPS on local disk? (Cassandra, Kafka)
  │   → I3/I4i (storage optimized)
  │
  └── GPU needed? (ML training, video processing)
      → P3/G4 (GPU)
```

---

## Sizing: How Much Is Enough?

**Starting point for a web app:**
- Single server: `t3.small` or `t3.medium` for dev
- Production: start with `m5.large`, monitor CPU/memory in CloudWatch, resize if needed

**Right-sizing tools:**
- AWS Compute Optimizer — analyzes your instances and recommends downsizing or upsizing
- CloudWatch metrics — CPU utilization, memory (requires CloudWatch agent)

**Rough rules of thumb:**
```
Web server (Node.js, Go, nginx): 2 vCPU, 2-4 GB RAM → t3.small/medium
Java/Spring Boot app:            2-4 vCPU, 4-8 GB   → t3.medium/m5.large
PostgreSQL database:             4 vCPU, 16-32 GB   → r5.large/xlarge
Elasticsearch:                   4-8 vCPU, 32+ GB   → r5.xlarge/2xlarge
Redis cache:                     2 vCPU, 8-16 GB    → r5.large
```

---

## Changing Instance Type

You can change an instance type at any time (requires a stop/start):

```bash
# Stop the instance
aws ec2 stop-instances --instance-ids i-1234567890abcdef0

# Wait for it to stop
aws ec2 wait instance-stopped --instance-ids i-1234567890abcdef0

# Change the type
aws ec2 modify-instance-attribute \
  --instance-id i-1234567890abcdef0 \
  --instance-type Value=m5.xlarge

# Start it back up
aws ec2 start-instances --instance-ids i-1234567890abcdef0
```

→ Continue to: `02-purchasing-options.md`
