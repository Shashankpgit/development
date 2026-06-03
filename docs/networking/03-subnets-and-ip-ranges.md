# Subnets and IP Ranges

## What is a subnet?

A subnet (short for subnetwork) is a slice of the VPC's IP address space, confined
to one region. While the VPC is global, subnets are regional.

Think of the VPC as the entire office building (global). Each floor belongs to one
city (region). A subnet is the allocation of space on that floor — you decide which
rooms (IPs) are on that floor and who gets them.

```
VPC: vault-vpc  (global)
│
├── asia-south1 (region)
│   └── vault-subnet: 10.0.0.0/24   ← subnet is tied to this region
│
└── us-central1 (region)
    └── another-subnet: 10.3.0.0/24  ← a different subnet in a different region
                                        (same VPC, different region)
```

Resources (VMs, GKE nodes) in a subnet get an IP from that subnet's range. They
can reach other subnets in the same VPC without any routing configuration.

---

## Two types of IP ranges in a GKE subnet

GKE in VPC-native mode uses **three** IP ranges on the same subnet:

```
Subnet: vault-subnet
│
├── Primary CIDR:   10.0.0.0/24   → NODE IPs       (one IP per node)
├── Secondary CIDR: 10.1.0.0/16   → POD IPs        (many IPs per node)
└── Secondary CIDR: 10.2.0.0/20   → SERVICE IPs    (one IP per service)
```

### Primary CIDR — node IPs

When a GKE node (a VM) is created, it gets one IP from the **primary CIDR**.

```
Node 1: 10.0.0.4
Node 2: 10.0.0.5
Node 3: 10.0.0.6
```

This is the node's network identity inside the VPC. When another resource in the VPC
wants to reach a node, it uses this IP.

### Secondary CIDR (pods) — pod IPs

Each Kubernetes pod gets an IP from the **pods secondary range**. This is what makes
GKE VPC-native.

Without VPC-native mode (routes-based mode), pods use the node's IP plus port
translation — pods are hidden behind the node. Only the node has a real network
identity.

With VPC-native mode, every pod is a first-class citizen of the VPC:
- Each pod has a real IP from `10.1.0.0/16`
- No port translation
- Any GCP resource in the VPC can reach a pod directly by its pod IP
- Cloud Load Balancers can health-check pods directly

```
Node 1 (IP: 10.0.0.4) hosts:
  Pod A: 10.1.0.1
  Pod B: 10.1.0.2
  Pod C: 10.1.0.3
  ...up to 110 pods per node by default

Node 2 (IP: 10.0.0.5) hosts:
  Pod D: 10.1.0.113   (GKE assigns a /24 block per node: 10.1.0.0, 10.1.1.0, etc.)
  Pod E: 10.1.0.114
```

GKE allocates a /24 block from the pods range to each node. Each node can host up
to ~110 pods (GKE's default per-node pod limit). A /16 pods range (65,536 IPs)
can serve 256 nodes × 256 IPs = enough for a large cluster.

### Secondary CIDR (services) — service IPs

A Kubernetes `Service` (type ClusterIP) is a stable virtual IP that load-balances
across a set of pods. Service IPs come from the **services secondary range**.

```
Service: vault-api-svc → 10.2.0.1
Service: keycloak-svc  → 10.2.0.2
Service: postgres-svc  → 10.2.0.3
```

Service IPs are not real network interfaces — they are virtual IPs managed by
`kube-proxy`. When a pod sends a request to `10.2.0.1`, kube-proxy rewrites the
destination to one of the pods backing that service.

---

## Alias IPs — the technology behind VPC-native pods

In traditional networking, a VM has one IP. In VPC-native GKE, each node has:
- 1 primary IP (from the subnet primary CIDR) — for the node itself
- 1 alias IP range (a /24 from the pods secondary CIDR) — for all pods on that node

An **alias IP** is an additional IP range assigned to a network interface. GCP
natively understands these — packets destined for `10.1.0.5` are automatically
routed to the node that owns the alias range containing `10.1.0.5`.

```
Without alias IPs (routes-based):
  Packet to pod 10.1.0.5
  → GCP doesn't know where 10.1.0.5 is
  → needs a static route: "10.1.0.0/24 → node 10.0.0.4"
  → these routes pile up: 256 routes for 256 nodes, approaching GCP's route limit

With alias IPs (VPC-native):
  Packet to pod 10.1.0.5
  → GCP knows node 10.0.0.4 owns alias 10.1.0.0/24
  → routes directly, no extra routes needed
  → scales to thousands of nodes without hitting limits
```

---

## The `secondary_ip_range` block in Terraform

```hcl
resource "google_compute_subnetwork" "subnet" {
  name          = "vault-subnet"
  ip_cidr_range = "10.0.0.0/24"    # primary — node IPs

  secondary_ip_range {
    range_name    = "pods"           # name referenced in GKE module
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"       # name referenced in GKE module
    ip_cidr_range = "10.2.0.0/20"
  }
}
```

The `range_name` values (`"pods"`, `"services"`) are passed to the GKE cluster:

```hcl
resource "google_container_cluster" "primary" {
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"      # must match secondary_ip_range name
    services_secondary_range_name = "services"  # must match secondary_ip_range name
  }
}
```

If these names don't match, the cluster creation fails with:
"ip_allocation_policy.cluster_secondary_range_name must be a secondary range of the subnetwork"

---

## Private Google Access

A subnet-level setting that allows VMs without public IPs to reach Google APIs
(Cloud Storage, BigQuery, Pub/Sub) without going through Cloud NAT.

```
VM (private IP only)
  → wants to read from a GCS bucket
  → Private Google Access enabled: packet goes to 199.36.153.8/30 (Google's API range)
  → GCP routes it internally to the API
  → no Cloud NAT needed for this specific case
```

We don't enable this in our stack (we use Cloud NAT for all external traffic),
but it appears on the exam.

---

## Common mistake: forgetting secondary ranges for GKE

The most frequent error when creating a GKE VPC-native cluster from scratch:

```
Error: googleapi: Error 400: Subnetwork is not configured to use VPC alias IP ranges
```

This means: the subnet exists, but `secondary_ip_range` blocks are missing.
Fix: add the pods and services secondary ranges to the subnet.

---

## GCP Cloud Exam Tips

- "VPC-native cluster" and "alias IP cluster" mean the same thing. The exam uses
  both terms.

- Routes-based clusters (the old default) are being deprecated. VPC-native is the
  only option for new clusters in recent GKE versions.

- The **subnet's primary CIDR** determines how many nodes you can have.
  A /24 allows ~251 nodes maximum.

- The **pods secondary CIDR** determines the maximum number of pods across the cluster.
  Each node gets a /24 block from this range (GKE default). A /16 pods range supports
  256 nodes (because 65536 / 256 = 256 node slots).

- You **cannot change a subnet's primary CIDR** after creation. You can expand it
  (make it larger) but cannot shrink it. Secondary ranges can be added but not
  modified once in use.

- "What allows VMs in a subnet to reach Google APIs like Cloud Storage without a
  public IP and without Cloud NAT?" → **Private Google Access** (subnet-level setting).

- VPC-native (alias IP) benefits for the exam:
  1. Pod IPs are natively routable in the VPC (no extra routes)
  2. Supports Network Policy (Calico or Dataplane V2)
  3. Works with GCP load balancer health checks reaching pods directly
  4. No route limit issues at scale
