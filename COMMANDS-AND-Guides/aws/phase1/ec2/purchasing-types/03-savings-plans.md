# EC2 Purchasing — 03: Savings Plans

> **Last updated:** July 6, 2026
> **Commit to a spend amount per hour (not a specific instance type) and get RI-level discounts with more flexibility.**

---

## What Is a Savings Plan?

A Savings Plan is AWS's newer, more flexible version of Reserved Instances. Instead of committing to a specific instance type, you commit to a **minimum hourly spend** for 1 or 3 years.

```
Reserved Instance: "I'll use m5.large in ap-south-1 for 1 year"
Savings Plan:      "I'll spend at least $0.10/hr on compute for 1 year"
```

AWS automatically applies the Savings Plan discount to your usage. If your actual spend matches what you committed, you pay the discounted rate. Anything beyond the commitment is billed On-Demand.

---

## The Three Types of Savings Plans

### 1. Compute Savings Plan

**Most flexible. Covers EC2, Lambda, and Fargate.**

```
Applies to:
  ✔ EC2 instances (ANY instance family, ANY size, ANY AZ, ANY region, ANY OS)
  ✔ AWS Lambda (per request + per GB-second)
  ✔ AWS Fargate (per vCPU-hour + per GB-hour)

Discount: Up to 66% vs On-Demand

Example:
  Commitment: $0.20/hr

  Monday: Running m5.large (costs $0.096/hr On-Demand)
          → Covered by plan, pay Savings Plan rate (~$0.058/hr)

  Tuesday: Switched to c5.xlarge (costs $0.170/hr On-Demand)
           → Still covered, Savings Plan applies automatically
           → If spend > $0.20/hr, excess at On-Demand
```

### 2. EC2 Instance Savings Plan

**Less flexible than Compute, but higher discount. Covers only a specific instance family + region.**

```
Applies to:
  ✔ EC2 instances in a specific instance FAMILY and REGION
  ✔ Any size within that family (like Regional Standard RI)
  ✔ Any AZ in that region
  ✔ Any OS

Discount: Up to 72% vs On-Demand (same as Standard RI)

Example:
  Commitment: m5 family in ap-south-1

  m5.large, m5.xlarge, m5.2xlarge, m6i.large → all covered
  c5.large → NOT covered (different family)
  m5.large in us-east-1 → NOT covered (different region)
```

### 3. SageMaker Savings Plan

Covers Amazon SageMaker ML instances. Not relevant for SAA-C03, skip for now.

---

## How Savings Plans Apply to Your Bill

Every hour, AWS applies your Savings Plan in this order:

```
Priority 1: EC2 Instance Savings Plan (most specific, applied first)
Priority 2: Compute Savings Plan (broadest, fills in the rest)
Priority 3: On-Demand (anything not covered by any plan)
```

**Visual example:**

```
Your hourly compute usage: $0.50/hr

Commitments you have:
  - EC2 Instance Savings Plan (m5, ap-south-1): $0.10/hr
  - Compute Savings Plan: $0.15/hr

How AWS applies it:
  $0.10 → covered by EC2 Instance SP (m5 instances in ap-south-1)
  $0.15 → covered by Compute SP (anything remaining: other regions, families, Lambda)
  $0.25 → billed at On-Demand rates (no plan covers this)
```

You pay: [EC2 Instance SP rate × $0.10 worth] + [Compute SP rate × $0.15 worth] + [$0.25 On-Demand]

---

## Commitment Amount — How to Choose

The key decision: **how many $/hr should I commit?**

AWS Cost Explorer helps you figure this out:

```
AWS Console → Cost Explorer → Savings Plans → Recommendations

It shows:
  → Your average hourly compute spend over last 7/30/60 days
  → Recommended commitment amount
  → Estimated annual savings
  → "Coverage" = what percentage of your usage would be covered
```

**Conservative approach:** Commit to 70-80% of your average steady-state usage.

```
Example:
  Average hourly compute spend (last 30 days): $1.20/hr
  Typical minimum (steady state): $0.80/hr
  Spikes (launches, batch jobs): up to $2.00/hr

  Safe commitment: $0.80/hr
  → 80% of steady-state usage covered at discounted rate
  → Spikes above $0.80/hr are On-Demand (more expensive but not a bad thing)
  → You never pay for an unused commitment
```

**Why not commit to $1.20/hr?**
If your usage drops (you scale down, kill some services), you're still charged the $1.20/hr commitment even if you only use $0.50/hr. The unused portion is wasted.

---

## Savings Plans vs Reserved Instances — The Decision

| | Savings Plans | Reserved Instances |
|--|--------------|-------------------|
| Commit to | $/hr spend | Specific instance type |
| Instance flexibility | Any (Compute SP) / Same family (EC2 SP) | Same family (Standard) / Any (Convertible) |
| Covers Lambda/Fargate | Yes (Compute SP) | No |
| Sellable | No | Yes (Standard RI) |
| Term options | 1 year, 3 years | 1 year, 3 years |
| Discount | Up to 66% (Compute) / 72% (EC2 Instance) | Up to 72% |
| Auto-applies | Yes | Yes |

**When to pick Savings Plans over RIs:**
- You run a mix of instance types and change them often → Compute Savings Plan
- You also run Lambda or Fargate → Compute Savings Plan covers all of it
- You want the simplest possible commitment → Savings Plans

**When to pick RIs over Savings Plans:**
- You want to sell unused capacity on the marketplace (Savings Plans can't be sold)
- You need AZ-specific capacity reservation (Savings Plans don't reserve capacity)
- You want the absolute maximum discount and you're locked into a specific instance → Standard RI

---

## Payment Options (Same as RIs)

```
All Upfront:     Pay the full 1/3-year commitment now
                 → Best overall discount (slightly better than Partial)

Partial Upfront: Pay ~50% now, rest as monthly commitment
                 → Middle discount

No Upfront:      Pay as a monthly commitment charge
                 → Slightly less discount, but no cash outlay
```

**Example: $0.10/hr Compute Savings Plan, 1 year**

```
On-Demand equivalent (no plan):  $876/year (0.10/hr × 8760)
Savings Plan (No Upfront):       ~$525-600/year depending on what you run
Savings:                         ~30-40%
```

---

## Monitoring Your Savings Plans

```bash
# View your active savings plans
aws savingsplans describe-savings-plans \
  --states active

# View savings plans utilization
aws ce get-savings-plans-utilization \
  --time-period Start=2026-06-01,End=2026-07-01

# Get coverage report (how much of your usage is covered)
aws ce get-savings-plans-coverage \
  --time-period Start=2026-06-01,End=2026-07-01 \
  --granularity MONTHLY

# Get recommendations
aws ce get-savings-plans-purchase-recommendation \
  --savings-plans-type COMPUTE_SP \
  --term-in-years ONE_YEAR \
  --payment-option NO_UPFRONT \
  --lookback-period-in-days THIRTY_DAYS
```

---

## Common Questions

### "Can I have both Savings Plans AND Reserved Instances?"

Yes. Many companies use both:
- Standard RIs for specific steady-state workloads (max discount)
- Compute Savings Plan for the rest (flexibility)

AWS applies the most specific discount first (RIs), then Savings Plans fill in the rest.

### "What happens if I commit too much?"

If your actual usage < your commitment:
- No Upfront: You're charged the committed hourly amount regardless. Wasted money.
- All Upfront: You already paid — the wasted hours are just lost money.

This is why you should commit conservatively (70-80% of steady-state).

### "Can I cancel a Savings Plan?"

No. Savings Plans are a 1 or 3 year commitment. You cannot cancel or sell them.
Choose carefully before purchasing.

### "Does the plan cover my whole account or just one region?"

- Compute Savings Plan: Covers your **entire AWS organization** if Consolidated Billing is enabled
- EC2 Instance Savings Plan: Covers a specific **instance family + region**, but applies across all accounts in the organization

→ Continue to: `04-spot-instances.md`
