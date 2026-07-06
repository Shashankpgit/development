# EC2 Purchasing — 02: Reserved Instances (RIs)

> **Last updated:** July 6, 2026
> **Commit to an instance type for 1 or 3 years, get 40–72% off. The details matter a lot.**

---

## What Is a Reserved Instance?

A **Reserved Instance (RI)** is a billing discount — not an actual instance. You make a commitment to AWS: "I'll use this type of instance in this region for 1 or 3 years." In exchange, AWS applies a significant hourly discount whenever you're running matching instances.

**The common confusion:** Buying an RI doesn't launch an instance. It creates a discount that automatically applies when your running On-Demand instances match the RI's specification.

```
You buy: 1 RI for m5.large, 1 year, ap-south-1
You launch: 1 On-Demand m5.large instance in ap-south-1

Result: AWS sees the match → applies the RI discount automatically to your bill
        Your instance runs normally — it just costs less per hour
```

---

## The Two Types: Standard vs Convertible

This is the most important distinction in RIs.

### Standard Reserved Instance

```
What you commit to:
  ✔ Instance family + size (e.g., m5.large)
  ✔ Region (e.g., ap-south-1)
  ✔ Operating System (Linux or Windows)
  ✔ Tenancy (default or dedicated)

Can you change it?
  ✔ Can change AZ (within the region)
  ✔ Can change instance size within the same FAMILY (e.g., m5.large → m5.xlarge)
      (called "instance size flexibility" — Linux only, regional scope only)
  ✘ Cannot change instance family (m5 → c5 not allowed)
  ✘ Cannot change region
  ✘ Cannot change OS (Linux ↔ Windows not allowed)

Discount: Maximum (up to 72% off On-Demand)
Sellable: Yes — on the AWS Reserved Instance Marketplace
```

### Convertible Reserved Instance

```
What you commit to:
  ✔ An equal or greater value of compute capacity for 1-3 years
  ✔ Region

Can you change it?
  ✔ Can change instance family (m5 → c5, r5, etc.)
  ✔ Can change instance size
  ✔ Can change OS
  ✔ Can change tenancy
  ✔ Can "convert" to a different RI (as long as new value ≥ old value)

Discount: Smaller (up to 54% off On-Demand)
Sellable: No — cannot be sold on the marketplace

Use case: You're not sure what instance type you'll need in 3 years.
          You want the commitment benefit but need flexibility to change.
```

---

## Payment Options

For each RI type, you choose how to pay:

| Payment Option | What It Means | Discount Level |
|---------------|---------------|----------------|
| **All Upfront** | Pay the entire 1/3 year cost now, $0/hr going forward | Highest |
| **Partial Upfront** | Pay some now, reduced hourly charge | Middle |
| **No Upfront** | Pay nothing now, discounted hourly charge | Lowest (still big savings) |

**Example: m5.large, 1 year, ap-south-1**

```
On-Demand:        $0.096/hr     → $841/year

1yr Standard RI:
  All Upfront:    $508 total    → $0.058/hr effective   (40% off)
  Partial Upfront: $260 now + $0.03/hr → $524/year      (38% off)
  No Upfront:     $0 now + $0.060/hr  → $526/year       (37% off)

3yr Standard RI:
  All Upfront:    $810 total    → $0.031/hr effective   (68% off)
  No Upfront:     $0 now + $0.052/hr  → $1,366 over 3yr (46% off)
```

**Choosing payment option:**
- Have cash upfront and confident the workload runs → All Upfront (best ROI)
- Want discount but keep cash for other things → No Upfront
- Somewhere in between → Partial Upfront

---

## RI Scope: Regional vs AZ-Specific

When you buy a Standard RI, you choose a scope:

### Regional Scope (recommended)

```
"This RI applies to any m5.large in ap-south-1 (any AZ)"

Benefits:
  ✔ Instance size flexibility — a m5.large RI can also cover 2× m5.small
  ✔ AZ flexibility — covers instances in any AZ in the region
  ✔ More likely to be used (instances in multiple AZs can benefit)
```

### AZ-Specific Scope

```
"This RI applies ONLY to m5.large in ap-south-1a"

Benefits:
  ✔ Capacity reservation — AWS guarantees capacity for that type in that specific AZ
  ✔ Useful if you MUST have instances in a specific AZ

Drawbacks:
  ✘ No instance size flexibility
  ✘ If all your instances move to AZ-b, the AZ-a RI is wasted
```

**Recommendation:** Use Regional scope unless you specifically need capacity reservation in a particular AZ.

---

## Instance Size Flexibility (Important Detail)

With a **Regional Standard RI** on Linux, you get **normalization factor** discounts across sizes in the same family.

AWS assigns a normalization factor to each size:

| Size | Normalization Factor |
|------|---------------------|
| nano | 0.25 |
| micro | 0.5 |
| small | 1 |
| medium | 2 |
| large | 4 |
| xlarge | 8 |
| 2xlarge | 16 |
| 4xlarge | 32 |

One `m5.large` RI (factor 4) can cover:
- 1× m5.large (factor 4 = 4) ✔
- 2× m5.small (2 × 2 = 4) ✔
- 4× m5.micro (4 × 0.5 = 2 — wait, 0.5×4=2, not 4. You'd need 8 micro for full coverage) ✔ partially
- 0.5× m5.xlarge (factor 8 — RI covers half the cost, other half On-Demand) ✔ partially

Example:
```
You bought: 1× m5.large Regional RI
You're running: 2× m5.small

→ Both m5.small instances are fully covered by the RI
   (2 small × factor 2 = factor 4 = exactly 1 large)
```

---

## How AWS Applies RI Discounts to Your Bill

Every hour, AWS looks at your running instances and your active RIs:

```
Step 1: Do you have running instances matching an RI spec?
Step 2: If yes → apply RI rate (instead of On-Demand rate) to those instances
Step 3: Any instances not covered by RIs → billed at On-Demand
```

**You don't do anything.** The discount is automatic.

**RI billing even when instance is stopped:**

```
Important: If you stop a matching instance, the RI is "wasted" that hour.
           You already paid for it (All/Partial Upfront) or you're charged the
           hourly RI fee (No Upfront).

A stopped instance still "consumes" the RI discount if there's nothing else running.
If nothing is running → you lose that hour's worth of commitment.
```

This is why RIs work best for **always-on workloads** (running 24/7/365).

---

## The Reserved Instance Marketplace

If you bought a Standard RI and no longer need it, you can sell it:

```
AWS Marketplace → EC2 Reserved Instances → Sell a Reserved Instance

You list:
  → RI type/term
  → Your price (you set it, can be less than AWS's current price)
  
Other AWS customers buy it from you.
AWS takes a 12% service fee from the sale.

Convertible RIs CANNOT be sold on the marketplace.
```

This is important for business flexibility — you're not locked in forever even with Standard RIs.

---

## The Zonal Reserved Instance (AZ-Specific) — Capacity Reservation

When you buy an AZ-specific RI, it does one extra thing: it **reserves capacity**.

```
Regional RI: Discounts your bill. Does NOT guarantee a physical instance is ready.
             (Rare: capacity unavailable errors can theoretically happen)

Zonal RI:    Discounts your bill AND reserves actual compute capacity in that AZ.
             When you launch a matching instance → it WILL launch (capacity is held).
```

For most use cases, this distinction doesn't matter (AWS has huge capacity). It matters for:
- Launch plans at exact times (batch jobs, disaster recovery failover)
- Regions with historically constrained capacity

---

## RI Recommendations in the Console

AWS **Compute Optimizer** and the **Cost Explorer** both recommend RIs based on your actual usage:

```
AWS Console → Cost Explorer → Savings Plans → Reserved Instance Recommendations

Shows:
  → "You've been running 3× m5.large On-Demand for 30 days
     Buy a 1yr Standard RI to save $XXX/year"
  → Estimated break-even date
  → Recommended payment option
```

---

## CLI: Working with Reserved Instances

```bash
# Describe your active RIs
aws ec2 describe-reserved-instances \
  --filters Name=state,Values=active \
  --query 'ReservedInstances[*].{
    ID:ReservedInstancesId,
    Type:InstanceType,
    Duration:Duration,
    State:State,
    Scope:Scope,
    FixedPrice:FixedPrice,
    UsagePrice:UsagePrice,
    Count:InstanceCount
  }' \
  --output table

# Check RI utilization (how much of your RI is being used)
aws ce get-reservation-utilization \
  --time-period Start=2026-01-01,End=2026-07-01 \
  --granularity MONTHLY

# Browse offerings before purchasing
aws ec2 describe-reserved-instances-offerings \
  --instance-type m5.large \
  --product-description "Linux/UNIX" \
  --offering-type "All Upfront" \
  --filters Name=duration,Values=31536000   # 1 year in seconds

# Purchase (after getting the offering ID from above)
aws ec2 purchase-reserved-instances-offering \
  --reserved-instances-offering-id <offering-id> \
  --instance-count 2

# List convertible RI exchange rates
aws ec2 get-reserved-instances-exchange-quote \
  --reserved-instance-ids <ri-id> \
  --target-configurations '[{"InstanceCount":1,"OfferedReservedInstancesId":"<new-offering-id>"}]'
```

---

## The Break-Even Analysis — When RIs Pay Off

```
m5.large, 1yr, No Upfront:
  RI rate:       $0.060/hr → $526/year
  On-Demand:     $0.096/hr → $841/year
  Break-even:    526/0.096 = 5,479 hours = ~7.5 months

If you run the instance for:
  < 7.5 months → On-Demand is cheaper
  > 7.5 months → RI is cheaper

If you run 24/7 for 1 year → RI saves $315/year (37%)
```

**Rule of thumb:** If usage is >50% of the year (>4,380 hours), an RI starts being more cost-efficient than On-Demand even at No Upfront pricing.

---

## Common Mistakes

### Mistake 1: Buying an RI for a dev instance that you stop at night

```
Dev instance: runs 8am-8pm, Mon-Fri
              = 12hr × 5days × 52wk = 3,120 hrs/year

RI cost (No Upfront): $0.060/hr × 8,760 = $526/year
  (You're billed 8,760 hours even when instance is off)

On-Demand:     $0.096/hr × 3,120 = $299/year

On-Demand wins here! You'd pay $526 for an RI but only actually use 3,120 hours.
```

### Mistake 2: Buying AZ-specific RI when your app moves to a different AZ

```
You bought: 3× m5.large in ap-south-1a
Your ASG shifted all instances to ap-south-1b (for capacity)

Result: RIs go unused — you're paying for them AND paying On-Demand for the AZ-b instances

Fix: Use Regional scope (AZ-flexible)
```

### Mistake 3: Forgetting Standard RI can't change instance families

```
You bought: Standard RI for m5.large
Two months later: You want to switch to c5.large

Standard RI: Stuck with m5. Sell it on the marketplace first.
Convertible RI: You could exchange it for a c5.large RI (if value ≥ m5.large RI)
```

→ Continue to: `03-savings-plans.md`
