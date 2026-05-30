# Phase 19 — Pure Infrastructure Automation (OpenTofu + Terragrunt)

## What we are doing

Automate the creation of every GCP resource the cluster needs using OpenTofu and
Terragrunt. One command creates the full infrastructure from zero.
`vault-automation/` and all Helm deployments are **not touched** — they continue to
run against whatever cluster this code produces.

## Scope: what this phase owns

| Resource | Why |
|---|---|
| GCS bucket | Remote state for OpenTofu (bootstrapped once, before anything else) |
| GCP project APIs | Container, Compute, IAM APIs must be enabled before any resource can be created |
| VPC + subnet | Private network for the cluster, with secondary IP ranges for pods/services |
| Cloud Router | Required for Cloud NAT (NAT needs a router to advertise routes) |
| Cloud NAT | Nodes need outbound internet — to pull images from GHCR and reach Let's Encrypt |
| Firewall rules | Ingress on 80/443, health checks from GCP LB, cluster-internal, egress HTTPS |
| Reserved static external IP | Fixes the LoadBalancer IP so DuckDNS never needs updating after a cluster recreate |
| GKE standard cluster | VPC-native, private nodes |
| Node pool | Worker nodes — machine type, count, disk |
| Node service account + IAM | Minimum roles for nodes to write logs, metrics, and pull images |

## Scope: what this phase does NOT touch

- `vault-automation/` — untouched
- Helm deployments — unchanged, run manually after the cluster exists
- Kubernetes resources (namespaces, cert-manager, ingress) — unchanged
- `global-secrets.yaml` — unchanged
- DuckDNS update — manual step (point to the reserved static IP this phase outputs)

---

## Tool choices

**OpenTofu** — open-source fork of Terraform (BSL licence controversy → community
fork). Identical HCL syntax, `tofu` replaces `terraform`, same providers and state.

**Terragrunt** — thin wrapper that solves three problems:

| Problem | Without Terragrunt | With Terragrunt |
|---|---|---|
| Remote state config | Copy-pasted into every module | Defined once in root `terragrunt.hcl` |
| Apply order | Manual — "remember: network before GKE" | `dependency {}` blocks, automatic |
| DRY inputs | project/region repeated everywhere | Set in root, all modules inherit |

---

## Directory layout

```
infra/
├── modules/                    # Reusable OpenTofu modules (logic)
│   ├── apis/                   # Enable GCP project APIs
│   ├── network/                # VPC, subnet, NAT, firewall, static IP
│   └── gke/                    # GKE cluster, node pool, node SA + IAM
│
└── live/                       # Terragrunt environment config (inputs)
    ├── terragrunt.hcl          # Root: GCS backend + google provider
    └── vault/                  # Environment name
        ├── apis/
        │   └── terragrunt.hcl
        ├── network/
        │   └── terragrunt.hcl
        └── gke/
            └── terragrunt.hcl
```

`modules/` = reusable logic.
`live/` = per-environment values that call those modules.
Adding a staging environment = add `live/staging/`. Nothing in `modules/` changes.

---

## Phases

### Phase 19.1 — Concepts KT

**Learn before writing a single line of HCL.**

Topics:
- What IaC is and why `gcloud` commands by hand don't scale
- OpenTofu: resources, data sources, variables, outputs, state, providers
- Terraform state: what it is, what "drift" means, why remote state is mandatory
- Terragrunt: the three problems it solves — DRY backend, dependency graph, shared inputs
- Module pattern: `modules/` (generic logic) vs `live/` (environment-specific values)
- `tofu plan` vs `tofu apply` vs `tofu destroy`
- GCP networking primer: VPC, subnet, firewall rules, Cloud NAT

Deliverable: `docs/kt/19-KT-iac-concepts.md`

---

### Phase 19.2 — Bootstrap

**One-time setup that cannot be done by OpenTofu itself.**

OpenTofu stores its state in a GCS bucket. That bucket must exist before `tofu init`
can run — it cannot be created by the same state it would hold. This is the bootstrap
problem. We solve it with a small shell script, then never touch it again.

Steps:
1. Install `tofu` and `terragrunt`
2. Authenticate: `gcloud auth application-default login`
3. Run `scripts/bootstrap.sh`:
   - Creates GCS bucket `gs://vault-tofu-state` with versioning enabled
   - Creates the GCP service account used by OpenTofu
   - Grants it the minimum roles: `roles/container.admin`,
     `roles/compute.admin`, `roles/iam.serviceAccountAdmin`,
     `roles/storage.admin`, `roles/serviceusage.admin`
4. Write `infra/live/terragrunt.hcl`:
   ```hcl
   remote_state {
     backend = "gcs"
     config = {
       bucket = "vault-tofu-state"
       prefix = "${path_relative_to_include()}"
     }
   }

   generate "provider" {
     path    = "provider.tf"
     content = <<EOF
   provider "google" {
     project = var.project_id
     region  = var.region
   }
   EOF
   }

   inputs = {
     project_id = "YOUR_GCP_PROJECT"
     region     = "asia-south1"
   }
   ```

What we teach:
- Why the bootstrap problem exists
- `generate` blocks: Terragrunt injects a `provider.tf` into every module automatically
- `path_relative_to_include()`: each module gets its own key in the GCS bucket so
  state files do not overwrite each other
- GCS bucket versioning: protects state from accidental corruption

Deliverable: `scripts/bootstrap.sh`, `infra/live/terragrunt.hcl`, state bucket exists.

---

### Phase 19.3 — APIs Module

**The first OpenTofu module — enable GCP APIs before anything else can be created.**

Every GCP resource requires its service API to be enabled. If you try to create a
GKE cluster before `container.googleapis.com` is enabled, you get an opaque 403 error.
Enabling APIs is a prerequisite for everything else so it gets its own module.

`infra/modules/apis/main.tf`:
```hcl
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",           # VPC, firewall, static IPs, Cloud NAT
    "container.googleapis.com",         # GKE cluster and node pools
    "iam.googleapis.com",               # Service accounts and IAM bindings
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com", # VPC-native networking
  ])
  service            = each.value
  disable_on_destroy = false            # Don't disable APIs when we destroy infra
}
```

`infra/live/vault/apis/terragrunt.hcl` references the module and passes `project_id`.
This module has no dependencies — it runs first.

What we teach:
- `for_each` with `toset()` — creating multiple similar resources without repetition
- `disable_on_destroy = false` — why we never disable APIs on destroy (other teams may
  use the same project, disabling breaks them)
- Why APIs are their own module instead of inline — they must be ready before any
  resource in any other module can be created

Deliverable: All required GCP APIs enabled.

---

### Phase 19.4 — Network Module

**VPC, subnet, Cloud NAT, firewall rules, and the reserved external IP.**

This is the most substantial module. Every other resource depends on it.

`infra/modules/network/main.tf` creates:

#### VPC and subnet

```hcl
google_compute_network           "vpc"
google_compute_subnetwork        "subnet"
  └── secondary_ip_range         "pods"      (e.g. 10.1.0.0/16)
  └── secondary_ip_range         "services"  (e.g. 10.2.0.0/20)
```

GKE VPC-native clusters require two secondary ranges on the subnet — one for pod IPs,
one for service IPs. Without them the cluster creation fails.

#### Cloud Router + Cloud NAT

```hcl
google_compute_router            "router"
google_compute_router_nat        "nat"
```

Why both are needed:
- Cloud NAT translates private node IP → public IP for outbound traffic
- Cloud Router is the control-plane component NAT advertises routes through
- Without NAT: nodes cannot reach GHCR to pull images, cert-manager cannot
  reach `acme-v02.api.letsencrypt.org`, any external API call fails silently

#### Reserved static external IP

```hcl
google_compute_address           "ingress_ip"   (type = EXTERNAL, region-level)
```

ingress-nginx gets a GCP LoadBalancer with an external IP. By default that IP is
ephemeral — it changes if the cluster is destroyed and recreated. A reserved static
IP is fixed forever. You set the DuckDNS IP once, never again.

This IP is passed as an output and used in `overrides/ingress-nginx.yaml`:
```yaml
controller:
  service:
    loadBalancerIP: <value from tofu output>
```

#### Firewall rules

Four rules, each with a specific job:

| Rule name | Direction | Source | Destination | Ports | Why |
|---|---|---|---|---|---|
| `allow-inbound-http-https` | INGRESS | 0.0.0.0/0 | nodes (tag: `gke-node`) | TCP 80, 443 | Internet traffic reaches ingress-nginx |
| `allow-gcp-health-checks` | INGRESS | 35.191.0.0/16, 130.211.0.0/22 | nodes | TCP 80, 443, 8443 | GCP LB health probes must reach ingress-nginx |
| `allow-internal` | INGRESS | subnet CIDR | nodes | all | Pod-to-pod and node-to-node traffic |
| `allow-egress-https` | EGRESS | nodes | 0.0.0.0/0 | TCP 443 | Nodes pull images, cert-manager reaches Let's Encrypt |

The health check rule is the most commonly forgotten. Without it, GCP's load balancer
marks every backend as unhealthy and returns 502 for all external traffic — even
though the pods are running fine.

`infra/modules/network/outputs.tf`:
- `network_name`, `subnet_name`
- `pods_range_name`, `services_range_name` (consumed by GKE module)
- `ingress_static_ip` (printed at the end — update DuckDNS to this value)

What we teach:
- Cloud NAT vs VPC peering vs public nodes — why NAT is the right choice
- GCP health check IP ranges (35.191.0.0/16, 130.211.0.0/22) — these are
  Google-internal and not advertised publicly; you have to know them
- Why the static IP must be reserved at the network layer, not in the GKE or
  Helm layer (reservation must exist before the LoadBalancer service is created)
- `network_tag` targeting on firewall rules — safer than targeting the whole VPC
  CIDR; nodes get a tag, rules target the tag

Deliverable: VPC, NAT, static IP, and all firewall rules created.

---

### Phase 19.5 — GKE Module

**The cluster and worker nodes, wired to the network.**

`infra/modules/gke/main.tf` creates:

#### Node service account + IAM

```hcl
google_service_account           "node_sa"
google_project_iam_member        "node_sa_log_writer"
  role = "roles/logging.logWriter"
google_project_iam_member        "node_sa_metric_writer"
  role = "roles/monitoring.metricWriter"
google_project_iam_member        "node_sa_monitoring_viewer"
  role = "roles/monitoring.viewer"
google_project_iam_member        "node_sa_metadata_writer"
  role = "roles/stackdriver.resourceMetadata.writer"
google_project_iam_member        "node_sa_artifact_reader"
  role = "roles/artifactregistry.reader"
```

These are the minimum roles GKE requires. Skip any one of them and monitoring breaks,
or node health reporting stops, or image pulls from Artifact Registry fail.
(For GHCR specifically, no GCP IAM is needed — just network egress, which NAT provides.)

#### GKE cluster

```hcl
google_container_cluster         "primary"
```

Key settings:
- `remove_default_node_pool = true` — always create cluster and node pool as
  separate resources; allows upgrading the pool without touching the control plane
- `networking_mode = "VPC_NATIVE"` — required for alias IP routing
- `ip_allocation_policy` — points at the secondary ranges from the network module
- `workload_identity_config` — enables pods to authenticate to GCP without JSON keys
- `network`, `subnetwork` — from network module outputs

#### Node pool

```hcl
google_container_node_pool       "nodes"
```

Key settings:
- `service_account` — the node SA created above (not the default compute SA)
- `oauth_scopes` — `cloud-platform` (broad but required for Workload Identity to
  intercept and scope down permissions per pod)
- `tags` — `["gke-node"]` — matches the firewall rules from the network module

`infra/modules/gke/variables.tf`:
- `network_name`, `subnet_name`, `pods_range_name`, `services_range_name`
  (all from network module)
- `machine_type` (e.g. `e2-standard-2`), `node_count`, `disk_size_gb`
- `k8s_version` (pin this — do not use `latest`)

`infra/modules/gke/outputs.tf`:
- `cluster_name`, `cluster_endpoint`, `cluster_ca_certificate`
- `get_credentials_command` — convenience: prints the exact `gcloud` command
  to configure `kubectl` after apply

`infra/live/vault/gke/terragrunt.hcl`:
- `dependency "network"` — reads network outputs, passes them as inputs
- `dependency "apis"` — ensures APIs are enabled before cluster creation

What we teach:
- Why node pool is separate from the cluster resource (independent lifecycle)
- `remove_default_node_pool` pattern — standard GKE best practice
- The difference between node SA roles and Workload Identity — node SA is for
  the node itself (kubelet, logs), Workload Identity is for pods
- Network tags matching firewall rules — the link between Phase 19.4 and this module

Deliverable: `tofu apply` in `live/vault/gke/` creates a working GKE cluster.

---

### Phase 19.6 — Wiring + One-Shot Apply

**The payoff. One command creates everything.**

Steps:
1. Verify all `dependency {}` blocks are correct
2. Add shared `inputs` to root `terragrunt.hcl` (project_id, region)
3. Run:

```bash
cd infra/live/vault
terragrunt run-all apply
```

Terragrunt builds the dependency graph:
```
apis  →  network  →  gke
```
Applies them left to right. Waits for each to complete before starting the next.

After apply, get cluster credentials:
```bash
# Output by gke module as a convenience:
gcloud container clusters get-credentials vault-cluster --region asia-south1

# Also outputs the reserved static IP — update DuckDNS once:
tofu -chdir=live/vault/network output ingress_static_ip
```

And to destroy everything:
```bash
terragrunt run-all destroy
```
Runs right to left automatically: `gke` first, then `network`, then `apis`.
This order matters — GKE holds references to the subnet; destroying network
before GKE would fail.

What we teach:
- `run-all` dependency resolution — how Terragrunt reads `dependency {}` blocks
  and builds the apply order
- Why destroy order is reverse of apply order (referenced resources must be
  freed before the resource they reference can be deleted)
- `--terragrunt-non-interactive` flag — required in CI

Deliverable: Entire GCP infra up in one command, torn down in one command.

---

### Phase 19.7 — CI/CD (GitHub Actions)

**Infrastructure changes go through PR review like any other code change.**

Two workflows:

| Workflow | Trigger | What it does |
|---|---|---|
| `tofu-plan.yml` | PR opened against `main` | `terragrunt run-all plan`, posts diff as PR comment |
| `tofu-apply.yml` | Merge to `main` | `terragrunt run-all apply` |

Authentication — **Workload Identity Federation** (no stored JSON key):
1. Create a Workload Identity Pool + Provider in GCP, linked to the GitHub repo
2. Store only the service account email in GitHub Secrets (not a key)
3. The `google-github-actions/auth` action exchanges a GitHub OIDC token for a
   short-lived GCP token — no long-lived credential exists anywhere

What we teach:
- Workload Identity Federation vs JSON key — why the key is a liability
- Plan-on-PR: reviewers see exactly what GCP will change before approving
- Why `apply` is only triggered on merge to `main`, not on every push

Deliverable: A PR changing `node_count` shows a plan comment with the exact diff
before anyone approves.

---

## Complete resource list

| GCP Resource | Module | Why |
|---|---|---|
| `google_storage_bucket` | bootstrap script | Remote state |
| `google_service_account` (OpenTofu SA) | bootstrap script | OpenTofu auth to GCP |
| `google_project_service` × 5 | apis | Enable required APIs |
| `google_compute_network` | network | VPC |
| `google_compute_subnetwork` | network | Subnet + pod/service ranges |
| `google_compute_router` | network | Required by Cloud NAT |
| `google_compute_router_nat` | network | Outbound internet for nodes |
| `google_compute_address` | network | Reserved static IP for ingress LB |
| `google_compute_firewall` allow-inbound-http-https | network | Internet → ingress on 80/443 |
| `google_compute_firewall` allow-gcp-health-checks | network | GCP LB probes → nodes |
| `google_compute_firewall` allow-internal | network | Pod-to-pod, node-to-node |
| `google_compute_firewall` allow-egress-https | network | Nodes → GHCR, Let's Encrypt |
| `google_service_account` (node SA) | gke | Identity for node pool workers |
| `google_project_iam_member` × 5 | gke | Minimum roles for the node SA |
| `google_container_cluster` | gke | GKE control plane |
| `google_container_node_pool` | gke | Worker nodes |

---

## Complete file list

| File | Phase |
|---|---|
| `docs/kt/19-KT-iac-concepts.md` | 19.1 |
| `scripts/bootstrap.sh` | 19.2 |
| `infra/live/terragrunt.hcl` | 19.2 |
| `infra/modules/apis/main.tf` | 19.3 |
| `infra/modules/apis/variables.tf` | 19.3 |
| `infra/live/vault/apis/terragrunt.hcl` | 19.3 |
| `infra/modules/network/main.tf` | 19.4 |
| `infra/modules/network/variables.tf` | 19.4 |
| `infra/modules/network/outputs.tf` | 19.4 |
| `infra/live/vault/network/terragrunt.hcl` | 19.4 |
| `infra/modules/gke/main.tf` | 19.5 |
| `infra/modules/gke/variables.tf` | 19.5 |
| `infra/modules/gke/outputs.tf` | 19.5 |
| `infra/live/vault/gke/terragrunt.hcl` | 19.5 |
| `.github/workflows/tofu-plan.yml` | 19.7 |
| `.github/workflows/tofu-apply.yml` | 19.7 |

---

## Dependency graph

```
apis
 └── network
       └── gke
```

Apply order: `apis` → `network` → `gke`
Destroy order: `gke` → `network` → `apis`

---

## Boundary with vault-automation/

```
This phase creates:             vault-automation/ uses:
──────────────────              ──────────────────────────────────────
GCS bucket (state)              All Helm charts (unchanged)
GCP APIs enabled                All Helm overrides (unchanged)
VPC + subnet + NAT              All kubectl / helm commands (unchanged)
Firewall rules                  global-secrets.yaml (unchanged)
Reserved static IP   ────────→  Set once in DuckDNS (manual, one-time)
GKE cluster + nodes  ────────→  kubectl context (one gcloud command)
```

When this phase finishes you have a cluster with a known external IP.
You run one `gcloud get-credentials` command, then `vault-automation/` works
exactly as it does today.
