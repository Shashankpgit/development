# Cloud Router

## The problem Cloud Router solves

When you send a packet from your laptop to a server, the packet travels through
dozens of routers. Each router looks at the destination IP and decides which
direction to forward the packet. Routers learn these paths by talking to each other
using a protocol called **BGP** (Border Gateway Protocol).

Inside a VPC, GCP handles all routing automatically — you don't configure individual
routes for pod-to-pod traffic. But when traffic needs to cross a boundary:
- From the VPC to the internet (Cloud NAT)
- From the VPC to an on-premises network (Cloud VPN or Cloud Interconnect)
- From the VPC to another VPC in a different region

…someone needs to advertise routes. **Cloud Router** is GCP's managed BGP speaker.
It tells the outside world "I can handle traffic for these IP ranges."

---

## What BGP is (enough to understand Cloud Router)

BGP is the protocol routers use to share routing information with each other.
Every BGP speaker has an **ASN** (Autonomous System Number) — a unique ID.

```
Your VPC (ASN: 64512) → tells Cloud NAT → "I have 10.0.0.0/24, forward traffic here"
Cloud NAT              → tells the internet → "return traffic for 10.0.0.x goes back to me"
```

You never configure the BGP sessions manually when using Cloud Router with NAT.
GCP manages it internally. You just create the router and attach NAT to it.

---

## Cloud Router as infrastructure

A Cloud Router is a GCP-managed resource. It is not a VM — it is a distributed
system running inside Google's network. You create it once and reference it by name.

```
Cloud Router sits between:
  Your VPC ←→ Cloud Router ←→ [Cloud NAT / Cloud VPN / Interconnect]
```

Cloud Router performs:
1. **Route advertisement**: tells external systems about the IP ranges in your VPC
2. **Route learning**: learns routes from external systems and programs them into
   your VPC's routing table

---

## Cloud Router in our stack

We use Cloud Router **only as a prerequisite for Cloud NAT**. No direct
configuration is needed — just create it and attach NAT.

```hcl
# modules/network/main.tf

resource "google_compute_router" "router" {
  name    = "vault-vpc-router"
  project = var.project_id
  region  = var.region            # Cloud Router is regional
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  router = google_compute_router.router.name   # NAT references the router
  ...
}
```

If you create NAT without a router, the API returns:
"router is required when nat_ip_allocate_option is AUTO_ONLY"

---

## Cloud Router for other use cases (beyond NAT)

### Cloud VPN

When extending an on-premises network into GCP using a VPN tunnel, Cloud Router
runs BGP between the GCP side and the on-premises router:

```
On-prem router (ASN: 65000)  ←BGP→  Cloud Router (ASN: 64512)
                                     ↕
                                    Your VPC
```

Learned routes from on-prem appear automatically in the VPC routing table.

### Cloud Interconnect

Same principle as VPN but with a dedicated physical link (not encrypted over the
public internet). Cloud Router still manages the BGP peering.

### Dynamic routing mode

Cloud Router has two modes for how it shares routes across regions within the VPC:

| Mode | What it does |
|---|---|
| Regional | Cloud Router only advertises subnets in its own region |
| Global | Cloud Router advertises all subnets in all regions of the VPC |

For multi-region setups (VPN + multiple regions), use global mode. For our single-
region setup, regional is fine (and is the default).

---

## What you do NOT need to configure

- The BGP sessions (GCP manages them for you when using Cloud NAT)
- Static routes (Cloud Router programs the VPC routing table automatically)
- BGP timers, MD5 authentication, or any BGP-specific tuning

You just create the resource and name it.

---

## GCP Cloud Exam Tips

- **Cloud Router is required for Cloud NAT**. The exam will ask "how do you give
  private VMs outbound internet access?" and the answer requires BOTH Cloud Router
  and Cloud NAT — not just one.

- **Cloud Router is regional**, not global. If you have subnets in multiple regions
  and need NAT in each, you create one Cloud Router per region.

- Cloud Router's role in Cloud VPN/Interconnect is **dynamic routing** — it makes
  on-premises routes appear inside the VPC automatically, without you having to
  add static routes manually. This is called a "dynamically routed VPN."

- When asked "which GCP service runs BGP?" — the answer is **Cloud Router**.

- Cloud Router does NOT forward packets by itself. It only manages routing
  information (the control plane). The actual packet forwarding is done by GCP's
  underlying networking fabric.

- "What is the difference between Cloud Router and a static route in GCP?"
  Static route: you manually define "to reach 192.168.1.0/24, go via 10.0.0.5."
  Cloud Router: routes are learned and propagated dynamically via BGP. When a new
  subnet is added on-prem, it appears in GCP automatically — no manual update needed.
