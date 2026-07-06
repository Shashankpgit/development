# EC2 Purchasing — 06: On-Demand Capacity Reservations

> **Last updated:** July 6, 2026
> **Reserve capacity without a financial commitment. The least-understood EC2 feature.**

---

## The Problem

AWS is generally very good at having capacity available. But there are situations where you absolutely need to guarantee instances will launch:

```
Scenario: Disaster Recovery
  You have a warm standby in us-east-1.
  Mumbai region (ap-south-1) goes down.
  You need to IMMEDIATELY launch 50× r5.2xlarge instances in us-east-1.
  
  Will capacity be available at that exact moment? Almost certainly yes.
  But "almost certainly" isn't good enough for DR failover.

Scenario: Scheduled Batch Job
  Every month-end, you need to launch 200 m5.xlarge for 4 hours.
  You can't risk the job failing because capacity is unavailable at midnight.

Scenario: Regulatory Requirement
  "System must be recoverable within 4 hours."
  You can't afford even a small chance of "InsufficientInstanceCapacity" error.
```

---

## What Is a Capacity Reservation?

An **On-Demand Capacity Reservation** reserves actual compute capacity in a specific AZ. AWS holds those slots for you, even if you're not running instances right now.

```
You create a reservation:
  Type: r5.2xlarge
  Count: 20
  AZ: us-east-1a
  
AWS response:
  "We've set aside 20× r5.2xlarge slots in us-east-1a for you."
  "Whenever you launch that instance type in that AZ, it will succeed."
  "We are holding this capacity right now."

You pay: On-Demand rate for those 20 slots
         Whether you're using them or not.
```

---

## Key Properties

```
✔ No term commitment (create/cancel anytime)
✔ Immediately effective (capacity is reserved within seconds)
✔ Works in a specific AZ (not region-wide)
✔ Counts toward Reserved Instance or Savings Plan billing if you have them
   → "Reserved Instance + Capacity Reservation" = guaranteed capacity at RI price
✔ Can be shared with other AWS accounts in your organization

✘ No discount — you pay On-Demand rate
✘ You pay whether you use the capacity or not
✘ AZ-specific only — doesn't move across AZs
```

---

## Capacity Reservation vs Zonal Reserved Instance

| | Zonal Reserved Instance | Capacity Reservation |
|--|------------------------|---------------------|
| Reserves physical capacity | ✔ | ✔ |
| Financial discount | ✔ (40-72% off) | ✘ (On-Demand rate) |
| Term commitment | Required (1 or 3 year) | None (cancel anytime) |
| Cost when unused | Same RI rate | On-Demand rate |
| Can combine for max benefit | ✔ | ✔ (combine with RI or Savings Plan) |

**Best combination:** Capacity Reservation + Regional Reserved Instance or Savings Plan

```
Capacity Reservation: Guarantees you can launch 20× r5.xlarge in us-east-1a
Regional Reserved Instance: Gives you a discounted rate for r5.xlarge usage

Combined effect:
  → Guaranteed capacity (from Capacity Reservation)
  → Discounted rate when running (from Reserved Instance)
  → No capacity risk for your DR plan
```

---

## Creating and Managing Capacity Reservations

```bash
# Create a capacity reservation
aws ec2 create-capacity-reservation \
  --instance-type r5.2xlarge \
  --instance-platform Linux/UNIX \
  --availability-zone us-east-1a \
  --instance-count 20 \
  --end-date-type unlimited    # runs until you cancel
  # or: --end-date-type limited --end-date 2026-12-31T23:59:59Z

# Output:
# {
#   "CapacityReservationId": "cr-0123456789abcdef0",
#   "State": "active",
#   "AvailableInstanceCount": 20,
#   "TotalInstanceCount": 20
# }

# List your reservations
aws ec2 describe-capacity-reservations \
  --query 'CapacityReservations[*].{
    ID:CapacityReservationId,
    Type:InstanceType,
    AZ:AvailabilityZone,
    Total:TotalInstanceCount,
    Available:AvailableInstanceCount,
    State:State
  }' \
  --output table

# Modify (scale up or down)
aws ec2 modify-capacity-reservation \
  --capacity-reservation-id cr-0123456789abcdef0 \
  --instance-count 30    # scaled up to 30

# Cancel the reservation
aws ec2 cancel-capacity-reservation \
  --capacity-reservation-id cr-0123456789abcdef0
```

---

## Launching an Instance Into a Capacity Reservation

When you launch an instance, you can specify how it uses capacity reservations:

```bash
# Option 1: Target a specific reservation
aws ec2 run-instances \
  --instance-type r5.2xlarge \
  --capacity-reservation-specification '{
    "CapacityReservationTarget": {
      "CapacityReservationId": "cr-0123456789abcdef0"
    }
  }'

# Option 2: Open preference — use any matching reservation if available, else On-Demand
aws ec2 run-instances \
  --instance-type r5.2xlarge \
  --availability-zone us-east-1a \
  --capacity-reservation-specification '{
    "CapacityReservationPreference": "open"
  }'

# Option 3: Explicitly avoid reservations (use normal On-Demand pool)
aws ec2 run-instances \
  --instance-type r5.2xlarge \
  --capacity-reservation-specification '{
    "CapacityReservationPreference": "none"
  }'
```

---

## Capacity Reservation Groups

You can put multiple capacity reservations into a **Capacity Reservation Group** (using AWS Resource Groups). Auto Scaling Groups can then target the group — it will spread instances across all reservations in the group.

```
Reservation Group: dr-failover-group
  ├── cr-aaaa: 10× r5.2xlarge in us-east-1a
  ├── cr-bbbb: 10× r5.2xlarge in us-east-1b
  └── cr-cccc: 10× r5.2xlarge in us-east-1c

ASG targeting this group:
  → Can launch up to 30 instances, spread across all three AZs
  → Guaranteed capacity in all three AZs
```

---

## When to Use Capacity Reservations

```
✅ Disaster recovery — you must be able to launch immediately on failover
✅ Scheduled batch jobs — you need capacity at a specific time
✅ Regulated workloads — compliance requires guaranteed recoverability
✅ Critical scheduled events (end-of-quarter processing, election night for a news site)
✅ When you want the COMBINATION of guaranteed capacity + RI discount

❌ General everyday workloads — AWS capacity is almost always available, you're wasting money
❌ Dev/test — unnecessary cost, just launch on-demand
❌ When you're not sure you need it — the On-Demand rate whether used or not adds up fast
```

---

## The Cost Trap

**Do not create capacity reservations and forget about them.**

```
Reservation: 20× r5.2xlarge in us-east-1a
r5.2xlarge On-Demand price: $0.504/hr

You're not running any instances there right now.
Cost per day: 20 × $0.504 × 24 = $241.92/day
Cost per month (30 days): $7,257.60

If you're not actually using this capacity → pure waste.

Always set an end date for short-term reservations:
  --end-date-type limited --end-date 2026-12-31T23:59:59Z

Or cancel immediately after your DR test / batch job completes.
```

---

## Summary: All Purchasing Types Side by Side

```
                  On-Demand  Savings Plan  Standard RI  Spot       Dedicated   Capacity Res.
─────────────────────────────────────────────────────────────────────────────────────────────
Discount          0%         40-66%        40-72%       70-90%     Higher $     0%
Commitment        None       1-3yr ($/hr)  1-3yr (type) None       Optional     None
Interruptible     No         No            No           Yes        No           No
Capacity reserve  No         No            Zonal RI: Yes No        No           Yes ✔
Hardware isolated No         No            No           No         Yes ✔        No
Cancel anytime    Yes        No            No (sell RI) Yes        No           Yes ✔
Best for          Flexible   Mixed fleet   Steady state Batch/ML   BYOL/Comply  DR/Scheduled
```

→ You've completed the Purchasing Types guide. Go back to `00-overview.md` for a refresher on the decision framework.
