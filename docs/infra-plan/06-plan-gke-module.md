# Plan 06 — GKE Module

## What we are building in this step

Four files:
```
infra/modules/gke/variables.tf
infra/modules/gke/main.tf
infra/modules/gke/outputs.tf
infra/live/vault/gke/terragrunt.hcl
```

This module creates the GKE cluster and node pool. It depends on the network module
for the VPC, subnet, and secondary range names.

---

## File 1: `infra/modules/gke/variables.tf`

### Block 1: project and region (shared by root)

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster (regional = spans all zones in the region)"
  type        = string
}
```

### Block 2: cluster and node pool names

```hcl
variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "vault-cluster"
}

variable "node_pool_name" {
  description = "Name of the GKE node pool"
  type        = string
  default     = "vault-nodes"
}

variable "node_sa_name" {
  description = "account_id of the GKE node service account (short name, not full email)"
  type        = string
  default     = "vault-gke-node-sa"
}
```

`node_sa_name` is the short ID of the service account (`vault-gke-node-sa`). The full
email is constructed as `${var.node_sa_name}@${var.project_id}.iam.gserviceaccount.com`
inside `main.tf`.

### Block 3: node configuration

```hcl
variable "machine_type" {
  description = "GCE machine type for worker nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "disk_size_gb" {
  description = "Size of each node's boot disk in GB"
  type        = number
  default     = 50
}

variable "k8s_version" {
  description = "Kubernetes minor version (e.g. '1.30'). GKE manages patch upgrades."
  type        = string
  default     = "1.30"
}

variable "node_tag" {
  description = "Network tag applied to nodes. Must match target_tags in firewall rules."
  type        = string
  default     = "gke-node"
}
```

`type = number` — node_count and disk_size_gb are numbers, not strings. This matters
because Terragrunt's `get_env()` always returns strings, and we need `tonumber()` when
passing them in `terragrunt.hcl`.

### Block 4: network variables (from network module outputs)

```hcl
variable "network_name" {
  description = "Name of the VPC (from network module output vpc_name)"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet (from network module output subnet_name)"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the pods secondary IP range (from network module)"
  type        = string
}

variable "services_range_name" {
  description = "Name of the services secondary IP range (from network module)"
  type        = string
}
```

These four variables have no defaults — they are required. They must be provided by
the Terragrunt `dependency.network.outputs.*` values. If Terragrunt cannot resolve
the dependency outputs, it uses the mock_outputs defined in `terragrunt.hcl`.

---

## File 2: `infra/modules/gke/main.tf`

### Block 1: Node service account

```hcl
resource "google_service_account" "node_sa" {
  account_id   = var.node_sa_name
  display_name = "GKE Node Pool Service Account"
  project      = var.project_id
}
```

`account_id` — the short name. GCP derives the full email as
`<account_id>@<project_id>.iam.gserviceaccount.com`.

`display_name` — human-readable name shown in the GCP IAM console. Not used in any
API calls or references.

This resource has no dependencies — it can be created before the cluster.

### Block 2: IAM role bindings (one resource per role)

```hcl
resource "google_project_iam_member" "node_sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}
```

`google_project_iam_member` — grants one role to one member. Using one resource per
role (instead of `google_project_iam_binding` which replaces the entire binding) means:
- Adding a role = add one resource
- Removing a role = remove one resource
- Each role shows as a separate line in `tofu plan`
- No risk of accidentally removing other roles that were manually granted

`member = "serviceAccount:${google_service_account.node_sa.email}"` — the format is
`<type>:<identifier>`. For a service account it is `serviceAccount:<email>`. Other
types: `user:<email>`, `group:<email>`.

`${google_service_account.node_sa.email}` — reads the `email` attribute from the SA
resource we defined above. Implicit dependency: SA must be created before IAM bindings.

Write 5 similar blocks for all 5 roles:
- `roles/logging.logWriter`
- `roles/monitoring.metricWriter`
- `roles/monitoring.viewer`
- `roles/stackdriver.resourceMetadata.writer`
- `roles/artifactregistry.reader`

### Block 3: GKE cluster

```hcl
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_name
  subnetwork = var.subnet_name

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false
  min_master_version  = var.k8s_version

  lifecycle {
    ignore_changes = [min_master_version]
  }
}
```

**`location = var.region`** — using a region (not a zone) creates a **regional cluster**.
The control plane runs across 3 zones in the region for HA. Zonal clusters (using
`us-central1-a`) have a single-zone control plane with no HA.

**`remove_default_node_pool = true` + `initial_node_count = 1`**

GKE requires `initial_node_count` when creating a cluster, even if you plan to remove
the default pool. The `1` is a placeholder — GKE creates one node in the default pool,
then OpenTofu immediately deletes the pool. The `google_container_node_pool` resource
(below) creates our actual node pool.

Why not embed the node pool in the cluster? Independent lifecycle — you can resize,
upgrade machine type, or replace the node pool without touching the control plane.

**`networking_mode = "VPC_NATIVE"`**

Enables alias IP networking. Without this, GKE uses routes-based networking (one
route per node, scaling problems beyond 100 nodes).

**`ip_allocation_policy`**

References the secondary ranges from the network module:
- `cluster_secondary_range_name` = `"pods"` (the `range_name` we set in the subnet)
- `services_secondary_range_name` = `"services"`

If these names don't match the subnet's secondary range names, cluster creation fails.

**`private_cluster_config`**

```hcl
enable_private_nodes    = true    # nodes have no public IP — secure
enable_private_endpoint = false   # API server has a public endpoint — kubectl works
master_ipv4_cidr_block  = "172.16.0.0/28"
```

`enable_private_endpoint = false` — you can reach the API server from your laptop.
Change to `true` in a zero-trust environment where kubectl runs from a bastion only.

`master_ipv4_cidr_block` — the CIDR for GKE's control plane VPC (which is peered
to our VPC). Must be a /28. Must NOT overlap with any range in our VPC (node subnet,
pods, services). `172.16.0.0/28` is safe because all our ranges use `10.x.x.x`.

**`workload_identity_config`**

```hcl
workload_pool = "${var.project_id}.svc.id.goog"
```

Enables Workload Identity for the cluster. The value is always in the format
`<project-id>.svc.id.goog`. This allows pods to authenticate to GCP APIs using
Kubernetes Service Accounts instead of JSON keys.

**`deletion_protection = false`**

By default, GKE 1.25+ sets `deletion_protection = true`. You cannot destroy the
cluster (even via `tofu destroy`) without first disabling this. We set it to `false`
so destroy works from the command line.

**`lifecycle { ignore_changes = [min_master_version] }`**

GKE auto-upgrades the control plane to the latest patch version within the minor
version. After the upgrade, the actual version is `1.30.x-gke.y`, but `min_master_version`
in state still says `"1.30"`. Without this lifecycle block, every `tofu plan` would show:

```
~ min_master_version: "1.30.x-gke.y" → "1.30"
```

This is a no-op diff (GKE already satisfies the `1.30` requirement). `ignore_changes`
prevents this noise.

### Block 4: Node pool

```hcl
resource "google_container_node_pool" "nodes" {
  name       = var.node_pool_name
  project    = var.project_id
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count
  version    = var.k8s_version

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = "pd-standard"
    service_account = google_service_account.node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = [var.node_tag]

    labels = {
      environment = "vault"
      managed-by  = "opentofu"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  lifecycle {
    ignore_changes = [version]
  }
}
```

**`cluster = google_container_cluster.primary.name`** — implicit dependency: cluster
must exist before the node pool.

**`node_config.service_account`** — the node SA we created above. Nodes authenticate
to GCP (Logging, Monitoring) using this SA.

**`oauth_scopes = ["cloud-platform"]`** — the OAuth scope granted to the node's SA
for making GCP API calls. `cloud-platform` is broad, but when Workload Identity is
enabled, individual pods use their own SA (scoped down by IAM). The broad scope is
never directly used by pod code.

**`tags = [var.node_tag]`** — network tags applied to the GKE nodes. These must
match the `target_tags = ["gke-node"]` in the firewall rules. If they don't match,
the firewall rules don't apply to the nodes — all external traffic is blocked.

**`labels`** — GCP resource labels (key-value metadata). Different from network tags.
Labels appear in billing reports and can be used to filter resources in the console.

**`shielded_instance_config`**

- `enable_secure_boot` — verifies that the node's boot firmware and kernel are
  signed. Prevents malicious boot-time modifications.
- `enable_integrity_monitoring` — creates a baseline of the boot measurements and
  alerts if they change (node was tampered with).

**`management { auto_repair, auto_upgrade }`**

- `auto_repair = true` — GKE automatically replaces nodes that fail health checks
- `auto_upgrade = true` — GKE keeps nodes on the latest GKE patch for the minor version

**`lifecycle { ignore_changes = [version] }`** — same as `min_master_version` on the
cluster. Without this, auto-upgrade creates noisy plan diffs.

---

## File 3: `infra/modules/gke/outputs.tf`

### Block 1: cluster outputs

```hcl
output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "External IP of the GKE control plane API server"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate (used by kubectl)"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}
```

`sensitive = true` — prevents OpenTofu from printing these values in plan/apply output.
They still exist in the state file (which is why the state bucket must have access
controls). Sensitive values can be referenced by other resources normally.

`master_auth[0].cluster_ca_certificate` — `master_auth` is a list attribute (even
though there's only one element). `[0]` accesses the first (only) element.

### Block 2: convenience outputs

```hcl
output "node_sa_email" {
  description = "Email of the GKE node service account"
  value       = google_service_account.node_sa.email
}

output "get_credentials_command" {
  description = "The exact gcloud command to configure kubectl"
  value = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
}
```

`get_credentials_command` — a pre-formatted string you can copy-paste directly.
This is printed by the `outputs` command in the orchestration script.

---

## File 4: `infra/live/vault/gke/terragrunt.hcl`

### Block 1: source and include

```hcl
terraform {
  source = "../../../modules/gke"
}

include "root" {
  path = find_in_parent_folders()
}
```

### Block 2: dependency on apis

```hcl
dependency "apis" {
  config_path = "../apis"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs                            = {}
}
```

Ordering dependency only. The GKE cluster cannot be created if `container.googleapis.com`
is not enabled. By declaring this dependency, `run-all apply` applies `apis` first.

### Block 3: dependency on network

```hcl
dependency "network" {
  config_path = "../network"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_name            = "mock-vpc"
    vpc_self_link       = "https://www.googleapis.com/compute/v1/projects/mock/global/networks/mock-vpc"
    subnet_name         = "mock-subnet"
    subnet_self_link    = "https://www.googleapis.com/compute/v1/projects/mock/regions/asia-south1/subnetworks/mock-subnet"
    pods_range_name     = "pods"
    services_range_name = "services"
    ingress_static_ip   = "0.0.0.0"
  }
}
```

`mock_outputs` are placeholder values used when running `terragrunt plan` before the
network module has been applied. They allow OpenTofu to validate the GKE module
configuration without real outputs existing.

Why does the mock `ingress_static_ip` appear here? The `ingress_static_ip` output
exists in the network module, and Terragrunt reads ALL outputs from a dependency —
even ones the current module doesn't use. Providing a mock for it prevents plan errors.

### Block 4: inputs

```hcl
inputs = {
  cluster_name    = get_env("CLUSTER_NAME", "vault-cluster")
  node_pool_name  = get_env("NODE_POOL_NAME", "vault-nodes")
  node_sa_name    = "vault-gke-node-sa"
  machine_type    = get_env("MACHINE_TYPE", "e2-standard-2")
  node_count      = tonumber(get_env("NODE_COUNT", "2"))
  disk_size_gb    = tonumber(get_env("DISK_SIZE_GB", "50"))
  k8s_version     = get_env("K8S_VERSION", "1.30")
  node_tag        = "gke-node"

  network_name        = dependency.network.outputs.vpc_name
  subnet_name         = dependency.network.outputs.subnet_name
  pods_range_name     = dependency.network.outputs.pods_range_name
  services_range_name = dependency.network.outputs.services_range_name
}
```

**`tonumber(get_env(...))`** — `get_env()` always returns a string. `node_count` and
`disk_size_gb` are declared as `type = number` in variables.tf. Without `tonumber()`,
OpenTofu raises a type mismatch error.

**`dependency.network.outputs.vpc_name`** — reads the `vpc_name` output from the
network module's applied state. This is how the GKE module knows the VPC name without
you typing it twice.

`node_sa_name = "vault-gke-node-sa"` and `node_tag = "gke-node"` are hardcoded here
(not from env vars) because they must match specific values used elsewhere in the
codebase. Making them env vars introduces the risk of typos breaking the firewall
rule tag match.

---

## Verification for this step

After `terragrunt apply` in `infra/live/vault/gke/`:

```bash
# Cluster exists and is RUNNING
gcloud container clusters list --project $GCP_PROJECT_ID

# Node pool is healthy
gcloud container node-pools list \
  --cluster vault-cluster \
  --region asia-south1 \
  --project $GCP_PROJECT_ID

# Nodes are ready (after get-credentials)
gcloud container clusters get-credentials vault-cluster \
  --region asia-south1 --project $GCP_PROJECT_ID

kubectl get nodes
# Expected: 2 nodes with STATUS = Ready

# Node SA exists
gcloud iam service-accounts list --project $GCP_PROJECT_ID | grep vault-gke-node-sa
```
