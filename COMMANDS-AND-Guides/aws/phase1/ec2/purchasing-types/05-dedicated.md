# EC2 Purchasing — 05: Dedicated Instances and Dedicated Hosts

> **Last updated:** July 6, 2026
> **Hardware isolation for compliance and software licensing. The most expensive options — understand when you actually need them.**

---

## The Problem They Solve

In AWS, multiple customers' instances run on the same physical hardware. AWS's hypervisor isolates them completely at the software level — one customer can never access another's data.

But some use cases require isolation at the **physical hardware level**:

```
Scenario 1: Compliance / Regulatory
  Your industry (banking, healthcare, government) requires
  that workloads run on hardware NOT shared with other companies.
  
  "Shared hardware? Even with software isolation? Our auditors won't accept that."

Scenario 2: Software Licensing (BYOL)
  Some enterprise software (Oracle Database, Windows Server, SQL Server)
  has licenses tied to the number of physical CPU sockets or cores.
  
  On shared hardware: you can't control which physical server your VM runs on.
  The license might technically require all cores on that server.
  
  On a Dedicated Host: you own the entire physical server.
  You know exactly how many sockets/cores it has. License accordingly.
```

---

## Dedicated Instance

### What It Is

Your EC2 instances run on **physical hardware dedicated to your AWS account** — not shared with any other AWS customer.

```
Normal instance:
  Physical server has:
    Customer A's instance (10.0.0.1)
    Customer B's instance (10.0.0.2)  ← different customer
    Customer C's instance (10.0.0.3)  ← different customer

Dedicated instance:
  Physical server has:
    Your Account's instances only
    Other customers can never land here
```

### What You Don't Control

- **You don't control which specific physical server** your instance runs on within AWS
- When you stop and start the instance, it might move to a different physical server (still dedicated to your account, but different hardware)
- You can't see the underlying hardware details (number of sockets, cores per socket, etc.)

### When to Use

```
✅ Compliance that requires hardware isolation from other customers
✅ Regulations that prohibit multi-tenant hardware
✅ NOT needed for BYOL licensing (you can't control the physical server layout)
```

### Cost

```
Dedicated Instance surcharge: $2.00/hr per region (regardless of how many instances)
                               + On-Demand rate per instance

Example: 3× m5.large Dedicated Instances in ap-south-1:
  $2.00/hr (region fee) + 3 × $0.096/hr (per instance) = $2.288/hr total
  
  Normal On-Demand: 3 × $0.096/hr = $0.288/hr
  Dedicated surcharge: +$2.00/hr (the isolation premium)
```

---

## Dedicated Host

### What It Is

You get an **entire physical server** allocated exclusively to you. You control how instances are placed on it.

```
Dedicated Host: Physical server belongs to you
  ├── 2 sockets
  ├── 48 physical cores total
  ├── You can run: 16× c5.xlarge, or 8× c5.2xlarge, or 4× c5.4xlarge
  │   (AWS defines how many instances of each type fit per host)
  └── No other customer's instances can ever be on this server
```

### What You Can See and Control

```
✔ Exact socket and core count of the physical server
✔ Which specific host your instances run on
✔ Host affinity: pin specific instances to specific hosts
✔ Host ID: stays the same (even after host maintenance events)
✔ Number of vCPUs used vs available
```

### Why This Matters for Licensing (BYOL)

```
Oracle Database license example:
  Oracle licenses by physical processor (socket)
  A typical Dedicated Host: 2 sockets × 24 cores = 48 cores

  With Dedicated Host:
    You know: 2 physical sockets
    Oracle license: 2 processor licenses needed
    Clear, auditable, compliant

  With normal EC2:
    You don't know how many sockets the physical server has
    Oracle's auditors may claim you need a license for ALL cores on the server
    Ambiguous, risky, potentially expensive
```

**Common BYOL scenarios:**
- Oracle Database Standard/Enterprise Edition
- Windows Server with Software Assurance
- SQL Server with SA
- SAP HANA
- VMware

### Cost

```
Dedicated Host pricing is per-host per hour (not per instance).

Example: Dedicated Host for c5 family in ap-south-1:
  $3.366/hr for the entire host
  
  On this host you can run:
    Up to 16× c5.xlarge  → $0.210/host/hr per instance
    Or 8× c5.2xlarge     → $0.421/host/hr per instance
    Or any combination that fits
    
  You pay the host fee whether you run 1 instance or 16 instances.
  → Maximize utilization to minimize effective cost per instance
```

**1-year or 3-year Reserved Dedicated Hosts** are also available:
```
1-year Dedicated Host (all upfront): up to 30% off On-Demand host rate
3-year: up to 60% off
```

---

## Host Affinity — Pinning Instances to Hosts

**Host affinity** lets you control that a specific instance always runs on a specific Dedicated Host.

```
Why:
  Some software licenses say "this instance must ALWAYS run on server X"
  If the instance moves to a different host (after stop/start), license auditors may flag it

How:
  instance.hostId = "h-0123456789abcdef0"  → always runs on this host
```

```bash
# Set host affinity when launching
aws ec2 run-instances \
  --instance-type c5.xlarge \
  --image-id ami-xxxx \
  --placement '{
    "HostId": "h-0123456789abcdef0",
    "Tenancy": "host",
    "Affinity": "host"     ← "host" = always this host; "default" = any host in fleet
  }'

# Modify affinity on an existing instance
aws ec2 modify-instance-placement \
  --instance-id i-xxxx \
  --affinity host \
  --host-id h-0123456789abcdef0
```

---

## Auto-Placement

When you have a pool of Dedicated Hosts, **auto-placement** lets AWS automatically choose which host to place new instances on.

```
You have: 3 Dedicated Hosts for c5 family
          Host 1: 10 slots used, 6 free
          Host 2: 5 slots used, 11 free
          Host 3: 0 slots used, 16 free

With auto-placement ON:
  New instance launch → AWS places it on Host 3 (most free slots)

With auto-placement OFF:
  New instance launch → You must specify which host
```

```bash
# Allocate a Dedicated Host with auto-placement enabled
aws ec2 allocate-hosts \
  --instance-type c5.xlarge \
  --availability-zone ap-south-1a \
  --auto-placement on \
  --quantity 2

# List your dedicated hosts
aws ec2 describe-hosts \
  --query 'Hosts[*].{
    HostId:HostId,
    Type:HostProperties.InstanceType,
    State:State,
    AvailableCapacity:AvailableCapacity.AvailableInstanceCapacity[0].AvailableCapacity,
    TotalCapacity:AvailableCapacity.AvailableInstanceCapacity[0].TotalCapacity
  }' \
  --output table

# Release a dedicated host (must have no running instances on it)
aws ec2 release-hosts --host-ids h-0123456789abcdef0
```

---

## Dedicated Instance vs Dedicated Host — The Comparison

| Feature | Dedicated Instance | Dedicated Host |
|---------|-------------------|----------------|
| Hardware isolation | ✔ Your account only | ✔ Your account only |
| See physical server details | ✘ | ✔ (sockets, cores) |
| Control instance placement | ✘ | ✔ (host affinity) |
| Same host across stop/start | ✘ (may move) | ✔ (with affinity) |
| BYOL licensing | Not reliable | ✔ (use this) |
| Cost model | Per-instance + $2/hr region fee | Per-host/hr |
| Pricing benefit from scale | None | Yes (pack more instances per host) |

**Rule:** 
- Need hardware isolation for compliance → Dedicated Instance (simpler, cheaper at small scale)
- Need BYOL licensing → Dedicated Host (only way to have control over physical layout)

---

## When You Actually Need These (And When You Don't)

```
Probably DON'T need Dedicated:
  → "Security" in a general sense → regular EC2 is already very secure
  → "I don't want to share with other customers" as a vague preference
     → AWS's hypervisor isolation is extremely robust
  → Running standard software with standard licenses
  → Healthcare apps (HIPAA) → AWS is HIPAA eligible with BAA on regular instances

Actually DO need Dedicated:
  → Your compliance auditor requires it in writing: "no multi-tenant hardware"
  → Oracle Database BYOL
  → Windows Server BYOL with Software Assurance
  → Specific government or financial regulations mandating physical isolation
```

---

## What the Exam Tests About Dedicated

| Question Pattern | Answer |
|----------------|--------|
| "Need to run Oracle with BYOL licensing" | Dedicated Host (need physical core visibility) |
| "Need hardware isolation from other customers" | Dedicated Instances OR Dedicated Host |
| "Which is most expensive?" | Dedicated Host (per-host fee) > Dedicated Instance > On-Demand |
| "Company needs to bring its own Windows Server license" | Dedicated Host |
| "What is the difference between Dedicated Instance and Dedicated Host?" | Host = you see physical hardware, control placement, same host on restart, BYOL. Instance = isolation only. |

→ Continue to: `06-capacity-reservations.md`
