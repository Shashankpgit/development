# EC2 — 00: Mental Model

> **Last updated:** July 5, 2026
> **Phase:** 1 — Foundation
> **Read this first.**

---

## What Is EC2?

**EC2 (Elastic Compute Cloud)** is AWS's virtual machine service. You rent a virtual server — choose the OS, CPU, memory, and storage — and AWS runs it in their data centers.

Think of it as renting a computer on the internet:
- Your laptop has a CPU, RAM, and a disk — so does an EC2 instance
- You install software, run applications, and stop/start it as needed
- You pay per hour of use (or per second for Linux instances)
- "Elastic" means you can change the size, or launch 1000 copies within minutes

---

## The EC2 Instance Lifecycle

```
NOT RUNNING
    │
    ▼ Launch (RunInstances API / Console)
PENDING
    │ (AWS allocating hardware, booting OS, running user data scripts)
    ▼
RUNNING  ←──────────────────────────────────────┐
    │                                           │
    ├──── Stop ──────► STOPPING ──► STOPPED ────┘ (can restart)
    │                               │
    │                               │ Terminate
    │                               ▼
    └──── Terminate ──► SHUTTING   TERMINATED
                         DOWN ──►  (cannot restart, instance gone)
```

**Stopped vs Terminated:**
- **Stopped:** Instance is off. EBS root volume still exists. You can restart it. **Charged for EBS storage**, not for compute.
- **Terminated:** Instance is deleted permanently. Root EBS volume deleted (by default). **Not charged** for anything.

**What happens to data when you stop/start:**
- EBS volume (attached disk): **data persists**
- Instance Store (ephemeral disk): **data is LOST on stop/terminate**
- RAM contents: **lost**
- Public IP: **changes** (unless Elastic IP)
- Private IP: **stays the same**

---

## The Key Concepts You'll See Everywhere

```
AMI (Amazon Machine Image)
  → The template: OS + pre-installed software + configuration
  → Like a disk image or Docker image for virtual machines
  → You pick an AMI when launching an instance

Instance Type
  → The hardware spec: CPU, RAM, network, GPU
  → e.g., t3.micro = 2 vCPU, 1GB RAM
  → e.g., r6g.2xlarge = 8 vCPU, 64GB RAM

Key Pair
  → SSH authentication: a public/private key pair
  → AWS stores the public key, you keep the private key (.pem file)
  → Used to SSH into the instance

Security Group
  → Virtual firewall (covered in VPC section)
  → Attached to the instance, controls inbound/outbound traffic

User Data
  → A script that runs automatically on first boot
  → Used to install software, configure the app
  → Runs as root, runs once at first launch

IAM Instance Profile
  → The role attached to EC2
  → Gives EC2 permission to call AWS services

Elastic IP (EIP)
  → A permanent public IP address
  → Unlike the auto-assigned public IP (which changes on stop/start)
```

---

## What's Next

| File | What It Covers |
|------|---------------|
| `01-instance-types.md` | CPU/memory families, how to choose the right type |
| `02-purchasing-options.md` | On-Demand vs Reserved vs Spot vs Savings Plans — the cost differences |
| `03-storage.md` | EBS volume types, instance store, snapshots, encryption |
| `04-ami-and-launch.md` | AMIs, user data scripts, key pairs, launching an instance |
| `05-networking.md` | ENI, Elastic IP, public vs private IP, Security Groups on EC2 |
| `06-ec2-in-practice.md` | Launch a server, install Nginx, create an AMI — hands-on |

→ Continue to: `01-instance-types.md`
