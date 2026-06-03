# VPC — Virtual Private Cloud

## The real-world analogy

Imagine GCP's global network as a massive, shared office building with thousands of
floors. Every company (GCP customer) rents one or more floors. The building's owner
(Google) manages the physical wiring, power, and security at the building level.

Your **VPC** is your private floor:
- Only your resources live there
- Google cannot read your traffic (it is encrypted at the infrastructure level)
- Other tenants cannot see or reach your floor
- You decide which rooms (subnets) exist and who can enter (firewall rules)

---

## What a VPC actually is

A **Virtual Private Cloud** is a logically isolated network inside GCP. It is not
a physical thing — GCP uses software-defined networking to simulate a private
network on top of Google's shared infrastructure.

Everything you create in GCP — GKE nodes, Cloud SQL, Compute VMs, App Engine —
must live inside a VPC. There is no such thing as a GCP resource "outside" a VPC.

---

## GCP VPC is GLOBAL (this is unusual)

Most cloud providers (AWS, Azure) create a VPC per region. GCP is different:
**one VPC spans all regions globally**.

```
AWS model (regional):
  us-east-1: VPC-A  → subnets only in us-east-1
  eu-west-1: VPC-B  → subnets only in eu-west-1
  To connect them: VPC Peering or Transit Gateway needed

GCP model (global):
  VPC: vault-vpc    → subnets in asia-south1, us-central1, europe-west1
                      all in the SAME VPC
  Resources across regions can communicate internally via the VPC
  No inter-region peering needed
```

**Why this matters:** Two GKE clusters in different regions can communicate privately
through the same VPC without any extra networking setup. Traffic never leaves Google's
internal backbone.

---

## Auto-mode vs Custom-mode VPC

GCP gives you two types when creating a VPC:

### Auto-mode VPC
- GCP automatically creates one subnet in every region
- Each subnet gets a preset CIDR from the `10.128.0.0/9` block
- Easy to start with, but you lose control over IP ranges
- Can convert to custom mode (one-way, no going back)
- NOT recommended for production — you cannot choose CIDRs

### Custom-mode VPC
- You create subnets explicitly in the regions you need
- You choose the CIDR for each subnet
- No accidental subnets you didn't ask for
- **This is what we use** (`auto_create_subnetworks = false`)

```hcl
# In modules/network/main.tf
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false   # custom mode
}
```

---

## VPC peering

If you have two VPCs and need resources in one to reach resources in the other,
you use **VPC Network Peering**. Traffic stays on Google's internal network.

```
VPC-A (10.0.0.0/16)  ←→  VPC-B (10.1.0.0/16)
     [peering connection]
```

**Rules:**
- CIDRs must not overlap (if both use 10.0.0.0/24, peering fails)
- Peering is not transitive: A↔B and B↔C does NOT mean A↔C
- Each side must explicitly accept the peering

**When you see it in our stack:** GKE creates a peering between your VPC and a
Google-managed VPC that hosts the GKE control plane. The CIDR `172.16.0.0/28`
in `private_cluster_config.master_ipv4_cidr_block` is for that peered network.
It must not overlap with anything in your VPC.

---

## Shared VPC

In enterprises, one GCP project owns the VPC and other projects attach to it. This
is called a **Shared VPC (XPN)**. All compute resources across 10 projects can share
one centrally managed network.

Not used in our stack (single project), but it appears on the PCNE exam.

---

## Default VPC

Every new GCP project comes with a default VPC (auto-mode, with subnets in every
region). **Never use the default VPC in production:**
- You cannot control its CIDRs
- It has overly permissive default firewall rules
- It does not signal intention — infrastructure-as-code always creates dedicated VPCs

---

## What lives inside a VPC

| Resource | Lives in VPC? | Notes |
|---|---|---|
| GKE nodes (VMs) | Yes | Get IPs from the subnet |
| Pods | Yes | Get IPs from the pods secondary range |
| Services (ClusterIP) | Yes | Get IPs from the services secondary range |
| Cloud SQL (private) | Yes (via VPC peering) | Appears in your VPC |
| Cloud Storage (GCS) | No | Accessed via API over the internet or Private Google Access |
| Cloud NAT | Yes | Attached to the VPC's router |
| Firewall rules | Yes | Applied to resources within the VPC |
| Load Balancers | Partially | The frontend IP is external; backends are in the VPC |

---

## VPC and our stack

```
VPC: vault-vpc
│
├── asia-south1
│   └── Subnet: vault-subnet  (10.0.0.0/24)
│       ├── GKE nodes          (IPs from 10.0.0.0/24)
│       ├── Pods               (IPs from 10.1.0.0/16)
│       └── Services           (IPs from 10.2.0.0/20)
│
├── Cloud Router: vault-vpc-router   (asia-south1)
├── Cloud NAT: vault-vpc-nat          (asia-south1)
├── Firewall rules (4)                (global — apply to all resources in VPC)
└── Static IP: vault-vpc-ingress-ip   (asia-south1, EXTERNAL)
```

---

## GCP Cloud Exam Tips

- GCP VPC is **global**. AWS VPCs are regional. This distinction appears in almost
  every GCP networking exam question comparing the two.

- **auto-mode VPC cannot be used with VPC peering** if the peer also uses auto-mode
  and the IPs conflict (both use 10.128.0.0/9). The exam tests this.

- "You need resources in project-A to access resources in project-B without public
  IPs" → Answer: **Shared VPC** (if one team manages networking) or **VPC Peering**
  (if both projects own their own VPCs).

- **Private Google Access**: enables VMs without public IPs to reach Google APIs
  (Cloud Storage, BigQuery) without going through Cloud NAT. It is enabled at the
  subnet level. Not the same as Cloud NAT — Cloud NAT is for external internet access,
  Private Google Access is for Google APIs only.

- The `google_compute_network` resource in Terraform creates the VPC.
  The `google_compute_subnetwork` resource creates subnets within it.
  These are always separate resources.

- When asked "what is created first, VPC or subnet?" — always the VPC. A subnet
  references the VPC by ID. Creating a subnet without a VPC fails.
