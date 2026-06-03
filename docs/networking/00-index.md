# GCP Networking — Learning Index

## What you will understand after reading all files in this directory

By the end you will be able to look at any GCP networking diagram, understand every
component, explain why each one exists, and recreate the full network from memory.
These are also the exact concepts that appear in the GCP Associate Cloud Engineer and
Professional Cloud Network Engineer certification exams.

---

## The stack we are building (one-line answer for each concept)

| Concept | One-line answer |
|---|---|
| CIDR | A way to write "this range of IP addresses" in one short notation |
| VPC | Your private, isolated network inside GCP — like owning your own floor in a building |
| Subnet | A portion of the VPC assigned to one region — a section of rooms on that floor |
| Primary IP range | Where node (VM) IPs come from |
| Secondary IP range | Where pod IPs and service IPs come from (GKE only) |
| Cloud Router | The BGP speaker that tells other networks how to reach yours |
| Cloud NAT | Gives private nodes outbound internet access without giving them public IPs |
| Firewall rules | Guards at every door — decide what traffic is allowed in and out |
| Static IP | An external IP that you reserve so it never changes |
| GKE networking | How all the above pieces connect when you add Kubernetes on top |

---

## Reading order

Read them in this order — each file builds on the previous one.

```
01-cidr-and-ip-addressing.md     ← Start here. Everything else uses CIDR.
02-vpc.md                        ← The container for everything else.
03-subnets-and-ip-ranges.md      ← Slicing the VPC into regions.
04-cloud-router.md               ← The routing brain.
05-cloud-nat.md                  ← Outbound internet for private nodes.
06-firewall-rules.md             ← Traffic control at every entry/exit.
07-static-ip.md                  ← Pinning the ingress address forever.
08-gke-networking.md             ← How Kubernetes sits on top of all of this.
09-flow-and-creation-order.md    ← The full picture + what to create first.
```

---

## Why networking matters before IaC

Every line of the `infra/modules/network/main.tf` file you just wrote corresponds to
a concept in these documents. When you read a Terraform plan and see:

```
+ google_compute_router_nat.nat
+ google_compute_firewall.allow_gcp_health_checks
```

…you should be able to answer: What does this create? Why does it need to exist?
What breaks if I remove it?

After reading these files, you can answer all of those questions.

---

## The big picture (before reading the details)

```
                        INTERNET
                           │
                    ┌──────▼──────┐
                    │  Static IP  │  ← reserved, never changes
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   GCP LB    │  ← created by ingress-nginx Service
                    └──────┬──────┘
                           │  (health checks from 35.191.x.x, 130.211.x.x)
              ┌────────────▼────────────┐
              │          VPC            │
              │  ┌────────────────────┐ │
              │  │      Subnet        │ │
              │  │  10.0.0.0/24       │ │  ← node IPs
              │  │  pods:  10.1.0.0/16│ │  ← pod IPs
              │  │  svcs:  10.2.0.0/20│ │  ← service IPs
              │  │                    │ │
              │  │  ┌──────────────┐  │ │
              │  │  │  GKE Nodes   │  │ │
              │  │  │ (no public IP│  │ │
              │  │  │   private)   │  │ │
              │  │  └──────┬───────┘  │ │
              │  └─────────┼──────────┘ │
              │            │ outbound   │
              │  ┌─────────▼──────────┐ │
              │  │   Cloud Router     │ │
              │  │   + Cloud NAT      │ │  ← gives nodes outbound internet
              │  └─────────┬──────────┘ │
              └────────────┼────────────┘
                           │
                        INTERNET
                    (GHCR, Let's Encrypt)
```

Firewall rules sit at the VPC boundary and control what enters and exits.

---

## How this maps to infra/modules/network/main.tf

```
main.tf resource                     → Concept file
────────────────────────────────────────────────────────────
google_compute_network               → 02-vpc.md
google_compute_subnetwork            → 03-subnets-and-ip-ranges.md
google_compute_router                → 04-cloud-router.md
google_compute_router_nat            → 05-cloud-nat.md
google_compute_address               → 07-static-ip.md
google_compute_firewall (×4)         → 06-firewall-rules.md
```
