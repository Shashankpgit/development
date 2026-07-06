# EC2 Purchasing — 01: On-Demand Instances

> **Last updated:** July 6, 2026
> **The baseline pricing model. No commitment, full flexibility.**

---

## What Is On-Demand?

On-Demand is the default. You launch an instance, you pay for every second it runs, you stop it and billing stops.

No upfront payment. No contract. No minimum. You can run it for 10 minutes or 10 years — the per-second rate is the same either way.

---

## How Billing Works Exactly

**Linux instances:** Billed per **second**, minimum 60 seconds.

```
Instance started: 10:00:00
Instance stopped: 10:00:45  → Billed for 60 seconds (minimum)
Instance stopped: 10:02:30  → Billed for 150 seconds
Instance stopped: 10:00:00 (next day = 24 hours) → Billed for 86,400 seconds
```

**Windows instances:** Billed per **hour**, minimum 1 hour.

```
Windows instance stopped after 20 min → Still charged 1 full hour
Windows instance stopped after 90 min → Charged 2 hours
```

**Stopped instances:**
- When you STOP (not terminate) an EC2 instance, **compute billing stops**.
- But the **EBS volume (root disk) continues to be charged** (~$0.08/GB-month for gp3).
- So a stopped `t3.medium` with a 20GB disk: no compute charge, ~$1.60/month for the disk.

---

## Real Pricing Examples (ap-south-1 — Mumbai)

```
t3.micro     2 vCPU,  1 GB    $0.0104/hr    $7.49/month
t3.small     2 vCPU,  2 GB    $0.0208/hr    $14.98/month
t3.medium    2 vCPU,  4 GB    $0.0416/hr    $29.95/month
t3.large     2 vCPU,  8 GB    $0.0832/hr    $59.90/month
t3.xlarge    4 vCPU, 16 GB    $0.1664/hr    $119.81/month
m5.large     2 vCPU,  8 GB    $0.096/hr     $69.12/month
m5.xlarge    4 vCPU, 16 GB    $0.192/hr     $138.24/month
c5.large     2 vCPU,  4 GB    $0.085/hr     $61.20/month
r5.large     2 vCPU, 16 GB    $0.126/hr     $90.72/month
```

**Note:** These are rough figures. Actual prices vary. Always check the [AWS Pricing Calculator](https://calculator.aws) for exact numbers.

---

## When On-Demand Is the Right Choice

### ✅ Short-term, unpredictable workloads

```
Scenario: You're running a 2-week hackathon project.
Analysis: Committing to 1 year makes no sense for a 2-week run.
Answer:   On-Demand. Pay for exactly what you use.
```

### ✅ Spiky traffic beyond your Reserved baseline

```
Scenario: You have 4 Reserved m5.large for your baseline traffic.
          During a product launch, you need 20 instances for 3 days.
Analysis: Those 16 extra instances run for 72 hours only.
Answer:   On-Demand for the burst. Reserved for the baseline.
```

### ✅ Testing a new instance type before committing

```
Scenario: You think c6g.xlarge (Graviton) will be faster and cheaper for your API.
Analysis: Don't buy a 3-year Reserved on something untested.
Answer:   Run On-Demand for 2 weeks → benchmark → then commit if it works.
```

### ✅ Development and testing environments

```
Scenario: Dev environment used 9am-6pm on weekdays. Off nights and weekends.
Analysis: 45 hrs/week × 52 weeks = 2,340 hrs/year vs 8,760 for always-on.
          Reserved is priced for always-on (8,760 hrs/year).
          On-Demand at 2,340 hrs < Reserved at 8,760 hrs even without the discount.
          
          OR: Even better — schedule the dev instance to stop at 6pm and start at 9am.
              That's ~$30/month on On-Demand vs $60/month always-on Reserved.
Answer:   On-Demand + stop/start scheduling.
```

---

## On-Demand Capacity Reservations (different from On-Demand instances)

A subtle variant: you can **reserve capacity** in a specific AZ at the On-Demand rate, without committing to a 1-year term.

```
Problem: Your app must launch 50 instances at exactly midnight (batch job).
         What if AWS doesn't have capacity available at that moment in your AZ?
         (Rare, but possible in very popular AZs during high-demand events.)

Solution: On-Demand Capacity Reservation
          "Reserve 50 m5.xlarge slots in ap-south-1a, available immediately when I need them."
          You pay the On-Demand rate whether you use the capacity or not.
          Cancel anytime.
```

This is covered in detail in `06-capacity-reservations.md`.

---

## On-Demand vs Other Options — When NOT to Use On-Demand

```
If you will run the instance 24/7 for 1+ year   → Use Reserved Instances or Savings Plans
If the workload is fault-tolerant and flexible  → Use Spot (70-90% cheaper)
If you need a specific instance type + region   → Use Reserved Instance
If you need any EC2/Lambda/Fargate flexibly     → Use Savings Plans
```

**The rule:** On-Demand is the expensive fallback. Always evaluate if Reserved or Savings Plans makes sense for your steady workloads.

---

## CLI: Launching an On-Demand Instance

```bash
# Launch an On-Demand instance (this is the default — no extra flags needed)
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.medium \
  --count 1 \
  --key-name my-key \
  --security-group-ids sg-xxxx \
  --subnet-id subnet-xxxx

# Check the billing per second (for Linux):
aws ec2 describe-instances \
  --instance-ids i-xxxx \
  --query 'Reservations[0].Instances[0].{
    State:State.Name,
    Type:InstanceType,
    LaunchTime:LaunchTime
  }'
```

---

## What the Exam Tests About On-Demand

| Question Pattern | Answer |
|----------------|--------|
| "Short-term workload, can't predict duration" | On-Demand |
| "Dev environment used only during business hours" | On-Demand (stop nights/weekends to save) |
| "Application needs to handle traffic spikes beyond the reserved baseline" | On-Demand for the burst |
| "Which is most expensive per hour?" | On-Demand (vs Reserved/Spot) |
| "Which requires NO commitment?" | On-Demand AND Spot (both have no commitment) |

→ Continue to: `02-reserved-instances.md`
