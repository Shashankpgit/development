# Plan 05 — Network Module

## What we are building in this step

Four files:
```
infra/modules/network/variables.tf
infra/modules/network/main.tf
infra/modules/network/outputs.tf
infra/live/vault/network/terragrunt.hcl
```

This is the largest and most important module. It creates every network resource
the GKE cluster depends on.

---

## File 1: `infra/modules/network/variables.tf`

All inputs the module expects. Values are provided by `live/vault/network/terragrunt.hcl`.

### Block 1: project_id and region (required by every module)

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region where subnet, Cloud Router, NAT, and static IP are created"
  type        = string
}
```

### Block 2: VPC name

```hcl
variable "vpc_name" {
  description = "Name of the VPC. Also used as a prefix for router, NAT, IP, and firewall rule names."
  type        = string
  default     = "vault-vpc"
}
```

`default` — if the caller does not provide this variable, use `"vault-vpc"`. Defaults
make variables optional. Variables without defaults are required.

We use `vpc_name` as a prefix for all child resources (`${var.vpc_name}-router`,
`${var.vpc_name}-nat`, etc.) so that all related resources share a recognisable naming
pattern in the GCP console.

### Block 3: subnet configuration

```hcl
variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "vault-subnet"
}

variable "subnet_cidr" {
  description = "Primary CIDR for the subnet. Node IPs are drawn from this range."
  type        = string
  default     = "10.0.0.0/24"
}
```

### Block 4: GKE secondary ranges

```hcl
variable "pods_range_name" {
  description = "Name of the secondary IP range for GKE pod IPs"
  type        = string
  default     = "pods"
}

variable "pods_cidr" {
  description = "CIDR for the pods secondary range. /16 = 65,536 pod IPs."
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_range_name" {
  description = "Name of the secondary IP range for GKE service ClusterIPs"
  type        = string
  default     = "services"
}

variable "services_cidr" {
  description = "CIDR for the services secondary range. /20 = 4,096 service IPs."
  type        = string
  default     = "10.2.0.0/20"
}
```

`pods_range_name` and `services_range_name` are string names (not CIDRs). These names
are passed to the GKE module via outputs, and the GKE module uses them in the
`ip_allocation_policy` block. They must match exactly.

### Block 5: node tag

```hcl
variable "node_tag" {
  description = "Network tag applied to GKE nodes. Firewall rules target this tag."
  type        = string
  default     = "gke-node"
}
```

The network tag is the link between firewall rules and GKE nodes. Firewall rules
specify `target_tags = ["gke-node"]`. GKE nodes get `tags = ["gke-node"]` in their
node pool config. The string must be identical in both places.

---

## File 2: `infra/modules/network/main.tf`

### Block 1: VPC

```hcl
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
}
```

`auto_create_subnetworks = false` — custom mode. Without this, GCP creates subnets
in every region automatically (auto-mode). We never want that in production.

This is the first resource that must be created. Everything else references it.
OpenTofu infers the dependency from references like `google_compute_network.vpc.id`.

### Block 2: Subnet

```hcl
resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_cidr

  secondary_ip_range {
    range_name    = var.pods_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = var.services_range_name
    ip_cidr_range = var.services_cidr
  }
}
```

`network = google_compute_network.vpc.id` — this reference creates an implicit
dependency. OpenTofu knows it must create the VPC before this subnet. No explicit
`depends_on` needed.

`ip_cidr_range` — the primary CIDR. Node IPs come from here.

`secondary_ip_range` blocks — two extra CIDR ranges on the same subnet, required
for GKE VPC-native mode. Each has:
- `range_name` — a string identifier used when referencing this range from the GKE
  cluster config
- `ip_cidr_range` — the actual CIDR

If you try to create a GKE VPC-native cluster pointing to a subnet without secondary
ranges, the error is:
```
Error: googleapi: Error 400: Subnetwork is not configured to use VPC alias IP ranges
```

### Block 3: Cloud Router

```hcl
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}
```

`"${var.vpc_name}-router"` — string interpolation. If `vpc_name = "vault-vpc"`,
the router name becomes `"vault-vpc-router"`. Interpolation in HCL uses `${}`.

`region` — Cloud Router is regional. It must be in the same region as the subnet
and Cloud NAT.

`network` — references the VPC (implicit dependency on the VPC).

### Block 4: Cloud NAT

```hcl
resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
```

`router = google_compute_router.router.name` — references the router we just
created (implicit dependency: router must exist before NAT).

`nat_ip_allocate_option = "AUTO_ONLY"` — GCP manages the external IPs for NAT.
No reserved IPs needed for the NAT itself (the ingress static IP is separate).

`source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"` — applies
NAT to ALL IP ranges (including pod IPs). If you use `ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES`,
pods cannot make outbound connections — only nodes can.

`log_config { filter = "ERRORS_ONLY" }` — log only NAT errors, not every connection.
Logging every connection creates millions of log entries and costs money.

### Block 5: Reserved static IP

```hcl
resource "google_compute_address" "ingress_ip" {
  name         = "${var.vpc_name}-ingress-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}
```

`address_type = "EXTERNAL"` — this is a public IP, reachable from the internet.
`INTERNAL` IPs are only reachable within the VPC.

`network_tier = "PREMIUM"` — routes traffic through Google's private global backbone
(better latency). `STANDARD` uses public internet routing to the region edge.

This resource has no dependencies — it can be created in parallel with the subnet,
router, and firewall rules.

### Block 6: Firewall rule — allow inbound HTTP/HTTPS

```hcl
resource "google_compute_firewall" "allow_inbound_http_https" {
  name    = "${var.vpc_name}-allow-inbound-http-https"
  project = var.project_id
  network = google_compute_network.vpc.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.node_tag]
}
```

`direction = "INGRESS"` — this rule controls traffic coming INTO the nodes.

`allow { protocol = "tcp" ports = ["80", "443"] }` — nested block. `allow` (or
`deny`) specifies what to do when traffic matches this rule.

`source_ranges = ["0.0.0.0/0"]` — for INGRESS rules, this is the source of traffic.
`0.0.0.0/0` = all IPs = anyone on the internet.

`target_tags = [var.node_tag]` — the rule only applies to VMs with this tag.
GKE nodes will have `tags = ["gke-node"]` in the node pool config.

### Block 7: Firewall rule — allow GCP health checks

```hcl
resource "google_compute_firewall" "allow_gcp_health_checks" {
  name    = "${var.vpc_name}-allow-gcp-health-checks"
  project = var.project_id
  network = google_compute_network.vpc.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8443"]
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]
  target_tags = [var.node_tag]
}
```

`source_ranges` — two CIDR blocks instead of one. These are GCP's internal health
check IP ranges. They are not on the public internet — you cannot `ping` them from
your laptop. GCP's load balancers send health probes from these ranges.

This rule is one of the most commonly missed rules in new GKE deployments. The symptom
(502 on all external traffic) does not point to a missing firewall rule — it looks like
an application error.

Port `8443` — included for the ingress-nginx validating webhook. When you apply an
`Ingress` resource, the Kubernetes API server calls back to ingress-nginx on port 8443
to validate the ingress object before accepting it.

### Block 8: Firewall rule — allow internal

```hcl
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.vpc.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "all"
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = [var.node_tag]
}
```

`protocol = "all"` — allows all protocols (TCP, UDP, ICMP, etc.) instead of
specifying individual protocols. Used here because Kubernetes internal traffic uses
various protocols.

`source_ranges = [var.subnet_cidr]` — traffic can only come from within the same
subnet (10.0.0.0/24). Traffic from outside the subnet is not allowed by this rule.

### Block 9: Firewall rule — allow egress HTTPS

```hcl
resource "google_compute_firewall" "allow_egress_https" {
  name    = "${var.vpc_name}-allow-egress-https"
  project = var.project_id
  network = google_compute_network.vpc.id

  direction = "EGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = [var.node_tag]
}
```

`direction = "EGRESS"` — this rule controls traffic going OUT from nodes.

For EGRESS rules, the field is `destination_ranges` (not `source_ranges`). The
destination is where the traffic is going to — in this case, anywhere on the internet.

`source_ranges` is not valid for EGRESS rules. Using it causes a Terraform error.

---

## File 3: `infra/modules/network/outputs.tf`

Outputs expose values from this module so other modules (gke) can consume them.

### Block 1: VPC outputs

```hcl
output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "Self-link of the VPC (full URL used by GKE cluster)"
  value       = google_compute_network.vpc.self_link
}
```

`self_link` — a full GCP API URL like:
```
https://www.googleapis.com/compute/v1/projects/my-project/global/networks/vault-vpc
```

Some GCP resources accept either the name or the self_link. The GKE cluster
`network` argument accepts both, but `self_link` is unambiguous across projects.

### Block 2: Subnet outputs

```hcl
output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_self_link" {
  description = "Self-link of the subnet"
  value       = google_compute_subnetwork.subnet.self_link
}
```

### Block 3: Secondary range name outputs

```hcl
output "pods_range_name" {
  description = "Name of the pods secondary IP range"
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "Name of the services secondary IP range"
  value       = var.services_range_name
}
```

These output the variable values directly (not resource attributes). The GKE module
needs these names to configure `ip_allocation_policy`.

### Block 4: Ingress IP output

```hcl
output "ingress_static_ip" {
  description = "Reserved external IP for the ingress-nginx LoadBalancer"
  value       = google_compute_address.ingress_ip.address
}
```

`google_compute_address.ingress_ip.address` — the actual IP address string (e.g.
`"35.200.100.1"`). `.address` is a computed attribute — GCP assigns the IP value
after the resource is created.

This output is printed by the orchestration script's `outputs` command and is what
you enter into DuckDNS.

---

## File 4: `infra/live/vault/network/terragrunt.hcl`

### Block 1: source and include

```hcl
terraform {
  source = "../../../modules/network"
}

include "root" {
  path = find_in_parent_folders()
}
```

Same pattern as the apis module. Source points to `infra/modules/network/`.

### Block 2: dependency on apis

```hcl
dependency "apis" {
  config_path = "../apis"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs                            = {}
}
```

`dependency "apis"` — tells Terragrunt: apply `apis` before applying `network`. If
you run `terragrunt run-all apply` from the `vault/` directory, Terragrunt reads
this and knows the order.

`config_path = "../apis"` — relative path to the dependency's terragrunt.hcl directory.

`mock_outputs_allowed_terraform_commands = ["validate", "plan"]` — when running
`terragrunt plan` on the network module before `apis` has been applied, Terragrunt
needs to read the outputs of `apis`. But `apis` has no outputs (it only enables APIs).
Without mock_outputs, plan would fail because there are no outputs to read. With
mock_outputs, Terragrunt substitutes empty values during plan.

`mock_outputs = {}` — empty because apis has no outputs. The empty map signals to
Terragrunt that mocks are available even though there's nothing to mock.

### Block 3: inputs from environment variables

```hcl
inputs = {
  vpc_name            = get_env("VPC_NAME", "vault-vpc")
  subnet_name         = get_env("SUBNET_NAME", "vault-subnet")
  subnet_cidr         = get_env("SUBNET_CIDR", "10.0.0.0/24")
  pods_range_name     = get_env("PODS_RANGE_NAME", "pods")
  pods_cidr           = get_env("PODS_CIDR", "10.1.0.0/16")
  services_range_name = get_env("SERVICES_RANGE_NAME", "services")
  services_cidr       = get_env("SERVICES_CIDR", "10.2.0.0/20")
  node_tag            = "gke-node"
}
```

`get_env("VPC_NAME", "vault-vpc")` — reads `VPC_NAME` from the environment (set by
sourcing `infra/infra.env`). Falls back to `"vault-vpc"` if the variable is not set.

`node_tag = "gke-node"` — hardcoded, not from an env var. This value must match
the `tags` in the GKE node pool (Plan 06). Hardcoding ensures it cannot be accidentally
changed to a non-matching value.

---

## Verification for this step

After `terragrunt apply` in `infra/live/vault/network/`:

```bash
# VPC exists
gcloud compute networks list --project $GCP_PROJECT_ID | grep vault-vpc

# Subnet exists with correct CIDRs
gcloud compute networks subnets describe vault-subnet \
  --region asia-south1 --project $GCP_PROJECT_ID

# Cloud Router exists
gcloud compute routers list --region asia-south1 --project $GCP_PROJECT_ID

# Cloud NAT exists
gcloud compute routers nats list \
  --router vault-vpc-router \
  --region asia-south1 \
  --project $GCP_PROJECT_ID

# Static IP is reserved
gcloud compute addresses list --region asia-south1 --project $GCP_PROJECT_ID

# All 4 firewall rules exist
gcloud compute firewall-rules list --project $GCP_PROJECT_ID \
  | grep vault-vpc
```
