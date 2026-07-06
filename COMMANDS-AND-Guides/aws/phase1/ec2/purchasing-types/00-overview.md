# EC2 Purchasing Types — Overview

> **Last updated:** July 6, 2026
> **This is the starting point. Read this before any other file in this directory.**

---

## The Core Idea

AWS has a lot of spare hardware sitting in data centers around the world. They want to maximize how much of it gets used. So they've created different ways for you to pay for compute — depending on how much flexibility you need vs how much money you want to save.

```
You need flexibility (start/stop anytime, unpredictable usage)?
  → Pay more (On-Demand)

You commit for 1-3 years?
  → Pay less (Reserved / Savings Plans)

You're okay with being interrupted?
  → Pay a LOT less (Spot)

You need your instances on isolated hardware (compliance/licensing)?
  → Pay more (Dedicated)
```

That's the entire mental model. Every purchasing option is a point on this tradeoff:

```
Flexibility ←────────────────────────────────── → Cost Savings

On-Demand   Capacity       Savings    Reserved      Spot
            Reservations   Plans      Instances

Most $$                                            Least $$
No commit                                          No commit but interruptible
```

---

## The 6 Purchasing Types at a Glance

| Type | Commitment | Interruptible | Discount | Best For |
|------|-----------|---------------|----------|---------|
| **On-Demand** | None | Never | 0% baseline | Unpredictable, short-term |
| **Savings Plans** | 1 or 3 yr ($/hr) | Never | 40–66% | Flexible long-term compute |
| **Reserved Instances** | 1 or 3 yr (instance type) | Never | 40–72% | Steady-state, known workload |
| **Spot** | None | Yes (2-min warning) | 70–90% | Fault-tolerant, batch, stateless |
| **Dedicated Instance** | Optional | Never | Higher cost | Hardware isolation, compliance |
| **Dedicated Host** | Optional | Never | Highest cost | BYOL, compliance, audit |

Bonus:
| **Capacity Reservation** | None (pay On-Demand rate) | Never | 0% | Reserve capacity without committing |

---

## How AWS Bills You

When an EC2 instance runs for 1 hour, AWS charges you based on whichever purchasing model that instance is running under:

```
Instance launched On-Demand?     → On-Demand rate for that hour
Instance matches a Savings Plan? → Covered by your plan commitment
Instance matches a Reserved RI?  → Covered by your RI commitment
Instance is a Spot request?      → Current Spot price for that hour
```

**Important:** Savings Plans and Reserved Instances don't assign a specific instance. They apply as a billing discount. The instance runs normally — it just gets a cheaper rate when your commitment covers it.

---

## Reading Order

| File | What It Covers |
|------|---------------|
| `01-on-demand.md` | The baseline — how per-second billing works, when it's the right choice |
| `02-reserved-instances.md` | Standard vs Convertible, scope (AZ vs Regional), marketplace, billing mechanics |
| `03-savings-plans.md` | Compute vs EC2 Instance Savings Plans, how AWS applies them automatically |
| `04-spot-instances.md` | Capacity pools, pricing, 2-minute interruption, Spot Fleet, ASG integration — the deep dive |
| `05-dedicated.md` | Dedicated Instance vs Dedicated Host, BYOL, host affinity |
| `06-capacity-reservations.md` | Reserve capacity without financial commitment |

→ Start with: `01-on-demand.md`
