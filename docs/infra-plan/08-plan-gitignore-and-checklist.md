# Plan 08 — .gitignore + Implementation Checklist

## .gitignore additions

Add these entries to the existing `.gitignore` at the repo root:

```gitignore
# ── OpenTofu / Terragrunt ─────────────────────────────────────────────────────

# Terragrunt's local module cache — generated on every run, never commit
.terragrunt-cache/

# OpenTofu's provider binaries and lock files — downloaded by 'tofu init'
**/.terraform/
*.tfstate
*.tfstate.backup
.terraform.lock.hcl

# Real config values — committed as .example only
infra/infra.env
```

### Why each entry

| Entry | Why gitignored |
|---|---|
| `.terragrunt-cache/` | Generated files + 50–100 MB provider binaries. Regenerated automatically. |
| `**/.terraform/` | Same as above, inside any nested directory. The `**` matches any subdirectory depth. |
| `*.tfstate` | State files should NEVER be on git. State can contain sensitive values (passwords, certificates). Always use remote state (GCS). |
| `*.tfstate.backup` | OpenTofu creates a backup before every apply. Same reason as above. |
| `.terraform.lock.hcl` | Provider version lock file. Optionally commitable (for reproducible builds). We exclude it to let each developer use the latest compatible version. |
| `infra/infra.env` | Contains your real GCP project ID. The `.example` file is committed as a template. |

---

## Implementation checklist — do in this order

Follow this exactly. Each step depends on the previous one.

### Phase 0: One-time prerequisites (not automated)

- [ ] Install `tofu`: https://opentofu.org/docs/intro/install/
- [ ] Install `terragrunt`: https://terragrunt.gruntwork.io/docs/getting-started/install/
- [ ] Install `gcloud`: https://cloud.google.com/sdk/docs/install
- [ ] Create a GCP project (or use an existing one)
- [ ] Note your GCP project ID

---

### Phase 1: Config and bootstrap

- [ ] Create `infra/infra.env.example` (template with no real values)
- [ ] Create `scripts/vault-infra.sh` with `login`, `create-backend`, `destroy-backend`
- [ ] Update `.gitignore` with the entries above
- [ ] Make the script executable: `chmod +x scripts/vault-infra.sh`
- [ ] Copy `infra/infra.env.example` to `infra/infra.env` (local, gitignored)
- [ ] Edit `infra/infra.env` — set `GCP_PROJECT_ID` at minimum
- [ ] Run: `./scripts/vault-infra.sh login`
- [ ] Run: `./scripts/vault-infra.sh create-backend`

Verify:
```bash
gcloud storage buckets list --project $GCP_PROJECT_ID | grep tofu-state
gcloud iam service-accounts list --project $GCP_PROJECT_ID | grep opentofu-sa
```

---

### Phase 2: Root Terragrunt config

- [ ] Create `infra/live/terragrunt.hcl` (Plan 03)
  - `locals` block reading from env vars
  - `remote_state` block with GCS backend + `path_relative_to_include()`
  - `generate "provider"` block injecting provider.tf into every module
  - `inputs` block with `project_id` and `region`

Verify (no modules yet, just confirm connection):
```bash
source infra/infra.env
cd infra/live/vault/apis
terragrunt plan 2>&1 | grep -E "Error|error"
# Should fail with "source ... does not exist" not a credentials error
```

---

### Phase 3: APIs module

- [ ] Create `infra/modules/apis/variables.tf` (Plan 04)
  - `project_id` variable
  - `region` variable with empty default
- [ ] Create `infra/modules/apis/main.tf` (Plan 04)
  - `google_project_service.apis` with `for_each = toset([...])`
  - `disable_on_destroy = false`
- [ ] Create `infra/live/vault/apis/terragrunt.hcl` (Plan 04)
  - `terraform { source = ... }`
  - `include "root" { ... }`

Apply:
```bash
source infra/infra.env
cd infra/live/vault/apis
terragrunt apply
```

Verify:
```bash
gcloud services list --project $GCP_PROJECT_ID --enabled | grep container
# should show: container.googleapis.com
```

---

### Phase 4: Network module

- [ ] Create `infra/modules/network/variables.tf` (Plan 05)
  - All 9 variables (project_id, region, vpc_name, subnet_name, subnet_cidr,
    pods_range_name, pods_cidr, services_range_name, services_cidr, node_tag)
- [ ] Create `infra/modules/network/main.tf` (Plan 05)
  - VPC (`google_compute_network`)
  - Subnet with secondary ranges (`google_compute_subnetwork`)
  - Cloud Router (`google_compute_router`)
  - Cloud NAT (`google_compute_router_nat`)
  - Static IP (`google_compute_address`)
  - 4 firewall rules (`google_compute_firewall` × 4)
- [ ] Create `infra/modules/network/outputs.tf` (Plan 05)
  - vpc_name, vpc_self_link, subnet_name, subnet_self_link
  - pods_range_name, services_range_name, ingress_static_ip
- [ ] Create `infra/live/vault/network/terragrunt.hcl` (Plan 05)
  - source + include
  - `dependency "apis"` with empty mock_outputs
  - `inputs` using `get_env()` for all network variables

Apply:
```bash
source infra/infra.env
cd infra/live/vault/network
terragrunt apply
```

Verify:
```bash
gcloud compute networks list --project $GCP_PROJECT_ID | grep vault-vpc
gcloud compute firewall-rules list --project $GCP_PROJECT_ID | grep vault-vpc
gcloud compute addresses list --region asia-south1 --project $GCP_PROJECT_ID
```

---

### Phase 5: GKE module

- [ ] Create `infra/modules/gke/variables.tf` (Plan 06)
  - project_id, region, cluster_name, node_pool_name, node_sa_name
  - machine_type, node_count, disk_size_gb, k8s_version, node_tag
  - network_name, subnet_name, pods_range_name, services_range_name (no defaults)
- [ ] Create `infra/modules/gke/main.tf` (Plan 06)
  - `google_service_account.node_sa`
  - 5 × `google_project_iam_member` for node SA roles
  - `google_container_cluster.primary` (private, VPC-native, Workload Identity)
  - `google_container_node_pool.nodes` (with node_tag matching firewall rules)
- [ ] Create `infra/modules/gke/outputs.tf` (Plan 06)
  - cluster_name, cluster_endpoint (sensitive), cluster_ca_certificate (sensitive)
  - node_sa_email, get_credentials_command
- [ ] Create `infra/live/vault/gke/terragrunt.hcl` (Plan 06)
  - source + include
  - `dependency "apis"` with empty mock_outputs
  - `dependency "network"` with full mock_outputs for all 7 network outputs
  - `inputs` using `get_env()` + `tonumber()` + `dependency.network.outputs.*`

Apply:
```bash
source infra/infra.env
cd infra/live/vault/gke
terragrunt apply
# Takes ~10–15 minutes for cluster creation
```

Verify:
```bash
gcloud container clusters list --project $GCP_PROJECT_ID
# STATUS should be RUNNING
```

---

### Phase 6: Complete orchestration script + run-all

- [ ] Add `plan`, `apply`, `destroy`, `outputs`, `_print_outputs`,
      `destroy_backend_resources` functions to `scripts/vault-infra.sh` (Plan 07)

Test the full flow:
```bash
source infra/infra.env

# Destroy everything first (since you applied module-by-module above)
./scripts/vault-infra.sh destroy

# Then test the full one-command apply
./scripts/vault-infra.sh apply

# Should print ingress IP at the end
./scripts/vault-infra.sh outputs
```

---

## Common errors and what they mean

| Error | Cause | Fix |
|---|---|---|
| `google: could not find default credentials` | `application-default login` not run | Run `./scripts/vault-infra.sh login` |
| `Error 403: Kubernetes Engine API has not been used` | APIs module not applied | Apply apis module first |
| `Subnetwork is not configured to use VPC alias IP ranges` | Secondary ranges missing from subnet | Check `secondary_ip_range` blocks in subnet |
| `Error: Unsupported argument "region"` | Module missing `variable "region"` | Add `variable "region" { default = "" }` to the module |
| `IP range conflicts` | Overlapping CIDRs | Check SUBNET_CIDR, PODS_CIDR, SERVICES_CIDR don't overlap |
| `Error reading dependency outputs` | Dependency not applied, no mock_outputs | Add `mock_outputs` to the dependency block |
| `Bucket already exists` | Running create-backend twice | Expected — script is idempotent, skips existing resources |
| `502 Bad Gateway` after deploy | Missing health check firewall rule | Verify `allow-gcp-health-checks` rule exists and has correct source ranges |
| `ImagePullBackOff` after deploy | Cloud NAT missing or not applied | Verify `google_compute_router_nat` was created successfully |
| `tonumber: cannot convert "2" to number` | Missing `tonumber()` in terragrunt.hcl | Wrap `get_env()` with `tonumber()` for numeric variables |

---

## Final directory structure after all steps

```
infra/
├── infra.env.example
├── infra.env                        ← gitignored, your real values
├── modules/
│   ├── apis/
│   │   ├── main.tf
│   │   └── variables.tf
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── gke/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── live/
    ├── terragrunt.hcl
    └── vault/
        ├── apis/
        │   └── terragrunt.hcl
        ├── network/
        │   └── terragrunt.hcl
        └── gke/
            └── terragrunt.hcl

scripts/
└── vault-infra.sh
```

Total files: 14 (excluding generated .terragrunt-cache/ and .terraform/ directories)
