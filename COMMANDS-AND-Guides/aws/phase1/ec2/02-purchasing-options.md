# EC2 — 02: Purchasing Options

> **Last updated:** July 5, 2026
> **On-Demand, Reserved, Savings Plans, Spot, and Dedicated — which to use when, with real cost examples.**

---

## Overview

AWS gives you multiple ways to pay for EC2. The more you commit, the more you save.

```
On-Demand        → Pay per second, no commitment   → Baseline price
Savings Plans    → Commit $/hr for 1-3 years       → ~40-60% off
Reserved         → Commit specific instance type   → ~40-72% off
Spot             → Use AWS spare capacity          → ~70-90% off (can be interrupted)
Dedicated Host   → Physical server just for you    → Most expensive
Dedicated Instance → Isolated hardware, not the full server → Expensive
```

---

## 1. On-Demand

**Pay for compute capacity by the second** (minimum 60 seconds), no upfront cost, no commitment.

**Price example:** `m5.large` in ap-south-1 = **$0.096/hr**

```
Running 1 m5.large for a month (24×30 = 720 hours):
  720 × $0.096 = $69.12/month
```

**When to use:**
- Short-term workloads
- Applications with unpredictable traffic
- Developing and testing
- When you can't predict how long you'll need it

**When NOT to use:**
- Anything you'll run for more than 1 year → Reserved or Savings Plans
- Batch jobs, fault-tolerant workloads → Spot

---

## 2. Reserved Instances (RIs)

**Commit to a specific instance type in a specific region for 1 or 3 years. Pay less per hour.**

```
Payment options:
  All Upfront     → Pay the full amount now, maximum discount
  Partial Upfront → Pay some now, some monthly
  No Upfront      → Pay monthly only, smaller discount
```

**Discount example for `m5.large` in ap-south-1:**

| Option | On-Demand | 1yr No Upfront | 1yr All Upfront | 3yr All Upfront |
|--------|-----------|----------------|-----------------|-----------------|
| $/hr   | $0.096    | $0.060         | $0.058          | $0.038          |
| Discount | 0%      | 37%            | 40%             | 60%             |

**1 year All Upfront:** $0.058 × 8,760 = $508 for the year vs On-Demand $841. **Saves $333/year per instance.**

**Types of Reserved Instances:**

| Type | Flexibility | Discount |
|------|------------|---------|
| Standard RI | Specific instance type, AZ or region | Highest (60-72%) |
| Convertible RI | Can change instance family, OS | Lower (~45-54%) |

**Standard RI:** "I commit to m5.large in ap-south-1 for 3 years."
**Convertible RI:** "I commit to computing capacity — I can change m5.large to c5.large later."

**When to use:** Steady-state production workloads — databases, always-on app servers.

**Selling RIs:** If you no longer need a Standard RI, you can sell it on the AWS Marketplace. Convertible RIs cannot be sold.

---

## 3. Savings Plans

**Savings Plans are more flexible than Reserved Instances.** Instead of committing to a specific instance type, you commit to a **spend amount per hour** (e.g., "$0.10/hr").

```
Reserved Instance: "I'll use 1 m5.large in ap-south-1 for 1 year"
Savings Plan:      "I'll spend $0.10/hr on EC2 for 1 year — use whatever type I want"
```

**Types:**

| Type | Applies to | Flexibility |
|------|-----------|------------|
| Compute Savings Plan | EC2, Lambda, Fargate | Any instance family, any region, any OS |
| EC2 Instance Savings Plan | EC2 only | Any size in a specific family + region |

**Example:**
- EC2 Instance Savings Plan for M family in ap-south-1
- Commitment: $0.10/hr
- You can freely switch between m5.large, m5.xlarge, m6i.large, etc.
- Anything beyond $0.10/hr is billed at On-Demand

**When to use:**
- When you want Reserved-level savings but need flexibility to change instance types
- When you're not sure which specific instance types you'll need long-term

---

## 4. Spot Instances

**AWS sells its unused EC2 capacity at 70-90% discounts. The catch: AWS can reclaim the instance with 2-minute warning.**

```
On-Demand m5.large:  $0.096/hr
Spot m5.large:       ~$0.015-0.030/hr (varies by supply/demand)
Savings:             ~70-85%
```

**The interruption:** When AWS needs the capacity back (another customer needs it), they give you 2 minutes notice, then terminate your instance.

**Handling interruptions:**
- Your app must handle being killed
- Save state frequently to S3 or EBS
- Design the job to resume from a checkpoint

**When Spot works well:**
```
✅ Batch processing (image/video processing, ETL)
✅ Big data jobs (Spark, Hadoop on EMR)
✅ Machine learning training jobs
✅ CI/CD build agents
✅ Web crawlers
✅ Anything that can be parallelized and retried
```

**When Spot does NOT work:**
```
❌ Production databases
❌ Anything stateful that can't afford to lose 2 minutes of state
❌ Jobs that MUST complete without interruption
```

### Spot Fleet and Spot Instance Pools

To reduce interruption risk, use **Spot Fleet** — spread your capacity request across multiple instance types and AZs. If one pool is reclaimed, others still run.

```json
{
  "TargetCapacity": 10,
  "LaunchSpecifications": [
    {"InstanceType": "m5.large",  "SpotPrice": "0.040"},
    {"InstanceType": "m5a.large", "SpotPrice": "0.040"},
    {"InstanceType": "c5.large",  "SpotPrice": "0.040"}
  ],
  "AllocationStrategy": "diversified"
}
```

---

## 5. Dedicated Instances vs Dedicated Hosts

These are for compliance and licensing scenarios.

### Dedicated Instance

```
Your EC2 instance runs on hardware dedicated to YOUR account.
Other AWS customers' instances don't run on the same physical server.
You don't control which specific server.
```

Use case: Compliance requirements that say workloads must not share hardware with other customers.

Cost: On-Demand pricing + dedicated instance surcharge (~$0.04/hr per region).

### Dedicated Host

```
You get an entire physical server allocated to you.
You control which specific hardware your instances run on.
You can see CPU cores and sockets.
```

Use case:
- **BYOL (Bring Your Own License):** Software licenses bound to physical cores (Oracle DB, Windows Server, SAP, SQL Server). With a Dedicated Host, you know exactly how many cores the server has.
- Strict compliance requirements.

Most expensive option — you're reserving entire physical hardware.

---

## Real-World Decision Guide

### Scenario 1: E-commerce website (3 m5.large, runs 24/7)

```
Option A: On-Demand    = 3 × $0.096 × 8760 = $2,523/year
Option B: 1yr Reserved = 3 × $0.060 × 8760 = $1,576/year  (saves $947)
Option C: 3yr Reserved = 3 × $0.038 × 8760 = $998/year    (saves $1,525)

Decision: Use 1-year or 3-year Reserved Instances
```

### Scenario 2: Batch video encoding (runs 8 hours a day, fault-tolerant)

```
On-Demand m5.2xlarge = $0.384/hr × 8hr/day × 30days = $92/month
Spot m5.2xlarge      = $0.060/hr × 8hr/day × 30days = $14/month  (saves 85%)

Decision: Use Spot Instances
```

### Scenario 3: Mixed — always-on base + spiky traffic

```
Normal traffic: 4 instances
Peak traffic:   20 instances

Strategy (Savings Plan + Spot):
  4 Reserved (base) + 16 Spot (burst) = handles peak, maximizes savings

As Auto Scaling scales out:
  Base 4 instances use Reserved capacity
  New instances use Spot (cheap)
  If Spot interrupted, Auto Scaling can also fall back to On-Demand
```

---

## Savings Plan vs Reserved Instance — Quick Comparison

| | Reserved Instance | Savings Plan |
|--|------------------|-------------|
| Commitment | Specific instance type | $/hr spend |
| Flexibility | Low (Standard) or Medium (Convertible) | High (Compute) |
| Covers Lambda/Fargate | No | Yes (Compute Savings Plan) |
| Sellable on marketplace | Yes (Standard) | No |
| Typical use | Single workload, known instance type | Mixed fleet, changing needs |

**AWS recommendation now:** Use Savings Plans unless you need the specific Convertible RI feature.

---

## Summary Table

| Option | Discount | Commitment | Interruption | Best For |
|--------|---------|-----------|-------------|---------|
| On-Demand | 0% | None | Never | Short-term, unpredictable |
| Savings Plan | 40-60% | 1 or 3 years | Never | Flexible long-term |
| Reserved (Standard) | 40-72% | 1 or 3 years | Never | Specific instance, stable |
| Reserved (Convertible) | 45-54% | 1 or 3 years | Never | Flexibility to change type |
| Spot | 70-90% | None | Yes (2-min notice) | Fault-tolerant batch |
| Dedicated Host | None (higher) | Optional 1-3yr | Never | BYOL, compliance |

→ Continue to: `03-storage.md`
