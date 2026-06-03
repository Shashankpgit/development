# Plan 02 — Directory Structure + Bootstrap

## What we are building in this step

Before writing any OpenTofu code, two things must exist:
1. The directory layout that organises all our files
2. The GCS bucket (OpenTofu's state storage) + OpenTofu service account

Neither of these can be created by OpenTofu itself — so we use a shell script
and `gcloud` commands for both.

---

## Part A — Directory structure

```
infra/                              ← everything IaC lives here
│
├── infra.env.example              ← template config file (committed to git)
│                                     user copies to infra/infra.env and edits
│
├── modules/                       ← reusable OpenTofu logic (no env-specific values)
│   ├── apis/                      ← enables GCP project APIs
│   ├── network/                   ← VPC, subnet, NAT, firewall, static IP
│   └── gke/                       ← cluster, node pool, node SA + IAM
│
└── live/                          ← environment-specific values + Terragrunt config
    ├── terragrunt.hcl             ← ROOT config: GCS backend + provider injection
    └── vault/                     ← "vault" is our environment name
        ├── apis/
        │   └── terragrunt.hcl
        ├── network/
        │   └── terragrunt.hcl
        └── gke/
            └── terragrunt.hcl

scripts/
└── vault-infra.sh                 ← orchestration script (login, create-backend, apply, etc.)
```

### Why `modules/` vs `live/`?

`modules/` contains generic logic with variables but no hardcoded values:
```
"Create a VPC with this name in this region" → takes name and region as variables
```

`live/vault/` calls the module and provides the actual values for our environment:
```
vpc_name = "vault-vpc"
region   = "asia-south1"
```

Adding a second environment (e.g. staging) means adding `live/staging/` with different
values. Nothing in `modules/` changes.

---

## Part B — Config file: `infra/infra.env.example`

This is the single file the user edits before running anything. It is the source
of truth for all configuration values.

### Block 1: GCP project settings

```bash
export GCP_PROJECT_ID="your-gcp-project-id"
export GCP_REGION="asia-south1"
```

`GCP_PROJECT_ID` — your GCP project ID (e.g. `vault-project-123456`). Find it with
`gcloud projects list` or in the GCP console.

`GCP_REGION` — the GCP region where the cluster and all network resources will live.
We use `asia-south1` (Mumbai). All resources in a region must use the same region.

### Block 2: State backend settings

```bash
export TF_STATE_BUCKET="your-project-id-tofu-state"
```

The name of the GCS bucket that stores OpenTofu state. Must be globally unique
across all of GCP (like a domain name — no two buckets in the world can have the
same name). Convention: `<project-id>-tofu-state`.

### Block 3: OpenTofu service account

```bash
export TOFU_SA_NAME="opentofu-sa"
```

Short name for the service account OpenTofu will authenticate as when calling GCP
APIs. The full email is derived automatically:
`opentofu-sa@<GCP_PROJECT_ID>.iam.gserviceaccount.com`

### Block 4: Network settings

```bash
export VPC_NAME="vault-vpc"
export SUBNET_NAME="vault-subnet"
export SUBNET_CIDR="10.0.0.0/24"

export PODS_RANGE_NAME="pods"
export PODS_CIDR="10.1.0.0/16"

export SERVICES_RANGE_NAME="services"
export SERVICES_CIDR="10.2.0.0/20"
```

`SUBNET_CIDR` — primary range. Node IPs come from here. /24 = 256 addresses (251
usable after GCP reserves 5). Supports up to ~251 GKE nodes.

`PODS_CIDR` — secondary range for pod IPs. /16 = 65,536 addresses. GKE allocates
a /24 block per node (256 pod IPs per node), so /16 supports up to 256 nodes.

`SERVICES_CIDR` — secondary range for Kubernetes service ClusterIPs. /20 = 4,096
addresses. More than enough for our app.

**Rule:** these three CIDRs must not overlap with each other.

### Block 5: GKE cluster settings

```bash
export CLUSTER_NAME="vault-cluster"
export NODE_POOL_NAME="vault-nodes"
export MACHINE_TYPE="e2-standard-2"
export NODE_COUNT="2"
export DISK_SIZE_GB="50"
export K8S_VERSION="1.30"
```

`MACHINE_TYPE` — `e2-standard-2` = 2 vCPU, 8 GB RAM. Enough to run all vault
app components (keycloak alone needs ~1 GB, postgres ~256 MB, vault-api ~256 MB).

`NODE_COUNT` — 2 nodes. Minimum for high availability: if one node is restarted,
the other keeps serving traffic.

`K8S_VERSION` — pin the minor version (e.g. `1.30`). GKE manages patch updates
(1.30.x) automatically. Without pinning, the plan shows constant diffs.

---

## Part C — Bootstrap script: `scripts/vault-infra.sh`

This script has multiple commands but we plan only the bootstrap functions here.

### Overall script structure

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_ENV="$REPO_ROOT/infra/infra.env"
LIVE_DIR="$REPO_ROOT/infra/live/vault"
```

`set -euo pipefail` — the script stops immediately if:
- any command fails (`-e`)
- any undefined variable is used (`-u`)
- any command in a pipe fails (`-o pipefail`)

This prevents silent failures where a command fails but the script keeps running.

`SCRIPT_DIR` — absolute path to the scripts/ directory, regardless of where
you run the script from.

`REPO_ROOT` — one level up from scripts/ — the repo root.

### Block: load_config function

```bash
load_config() {
  if [[ ! -f "$INFRA_ENV" ]]; then
    error "Config file not found: $INFRA_ENV
Copy infra/infra.env.example → infra/infra.env and fill in your GCP project ID."
  fi
  source "$INFRA_ENV"
}
```

`source "$INFRA_ENV"` — runs the file in the current shell. All `export` statements
in `infra.env` become environment variables in this shell AND all child processes
(gcloud, terragrunt, tofu). This is what makes Terragrunt's `get_env("GCP_PROJECT_ID")`
work — the variable is already in the environment by the time terragrunt runs.

### Block: check_prerequisites function

```bash
check_prerequisites() {
  for cmd in gcloud tofu terragrunt; do
    if ! command -v "$cmd" &>/dev/null; then
      error "$cmd not found. Install it before running."
    fi
  done
}
```

`command -v "$cmd"` — checks if a command exists in PATH without running it.
`&>/dev/null` — suppresses all output (stdout + stderr). We only care about the
exit code.

### Block: login function

```bash
login() {
  load_config
  gcloud auth login
  gcloud config set project "$GCP_PROJECT_ID"
  gcloud auth application-default login
}
```

Two separate auth commands are needed:
- `gcloud auth login` — authenticates `gcloud` itself (for running gcloud commands)
- `gcloud auth application-default login` — creates credentials that OpenTofu uses
  when calling GCP APIs (`~/.config/gcloud/application_default_credentials.json`)

Without `application-default login`, `tofu apply` fails with:
`Error: google: could not find default credentials`

### Block: create_backend_resources function

This is the core bootstrap function. It creates resources that cannot be managed
by OpenTofu itself.

```bash
create_backend_resources() {
  load_config
  local SA_EMAIL="${TOFU_SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

  # Step 1: Create the GCS state bucket
  # Step 2: Enable versioning
  # Step 3: Create the OpenTofu service account
  # Step 4: Grant IAM roles to the SA
  # Step 5: Grant the SA access to the bucket
  # Step 6: Print summary
}
```

**Step 1 — Create GCS bucket (idempotent):**

```bash
if gcloud storage buckets describe "gs://${TF_STATE_BUCKET}" \
     --project="$GCP_PROJECT_ID" &>/dev/null; then
  warn "Bucket already exists — skipping"
else
  gcloud storage buckets create "gs://${TF_STATE_BUCKET}" \
    --project="$GCP_PROJECT_ID" \
    --location="$GCP_REGION" \
    --uniform-bucket-level-access
fi
```

Why check before creating? Running the script twice should not fail. `gcloud storage
buckets create` errors if the bucket already exists. Checking first makes the script
idempotent.

`--uniform-bucket-level-access` — disables per-object ACLs. All access controlled
via IAM only. Required for modern GCS security posture.

**Step 2 — Enable versioning:**

```bash
gcloud storage buckets update "gs://${TF_STATE_BUCKET}" --versioning
```

Versioning keeps all previous versions of the state file. If OpenTofu corrupts the
state (rare but possible), you can restore from GCS object history.

**Step 3 — Create SA (idempotent):**

```bash
if gcloud iam service-accounts describe "$SA_EMAIL" \
     --project="$GCP_PROJECT_ID" &>/dev/null; then
  warn "Service account already exists — skipping"
else
  gcloud iam service-accounts create "$TOFU_SA_NAME" \
    --project="$GCP_PROJECT_ID" \
    --display-name="OpenTofu Infrastructure Automation"
fi
```

**Step 4 — Grant IAM roles (loop):**

```bash
local roles=(
  "roles/container.admin"
  "roles/compute.admin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.serviceAccountUser"
  "roles/storage.admin"
  "roles/serviceusage.serviceUsageAdmin"
)

for role in "${roles[@]}"; do
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$role" \
    --quiet
done
```

`--quiet` suppresses the policy display after each binding. Without it, gcloud
prints the entire IAM policy (hundreds of lines) for every role.

`add-iam-policy-binding` is idempotent — running it twice on the same role does
not error and does not create a duplicate binding.

**Step 5 — Grant bucket access:**

```bash
gcloud storage buckets add-iam-policy-binding "gs://${TF_STATE_BUCKET}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"
```

The SA needs `objectAdmin` on the bucket specifically (not just at project level)
because the state files are GCS objects inside the bucket.

### Block: remaining commands (plan, apply, destroy, outputs)

These are covered in Plan 08 (orchestration script), once all the modules are planned.

### Block: main entrypoint

```bash
case "${1:-}" in
  login)            login ;;
  create-backend)   create_backend_resources ;;
  plan)             plan ;;
  apply)            apply ;;
  destroy)          destroy ;;
  destroy-backend)  destroy_backend_resources ;;
  outputs)          outputs ;;
  *)  error "Unknown command. Run '$0 help'." ;;
esac
```

`case` dispatches to the right function based on the first argument. `${1:-}` means
"first argument, or empty string if not provided" — prevents the `-u` flag from
erroring when no argument is given.

---

## Part D — .gitignore additions

Add these entries to the existing `.gitignore`:

```
# OpenTofu / Terragrunt — generated files, never commit
.terragrunt-cache/
**/.terraform/
*.tfstate
*.tfstate.backup
.terraform.lock.hcl

# Config with real project values — keep off git
infra/infra.env
```

`.terragrunt-cache/` — Terragrunt's local cache directory. Contains generated
`backend.tf` and `provider.tf` files and downloaded modules. Regenerated on every
run. Never commit.

`**/.terraform/` — OpenTofu's provider cache. Downloaded providers are large binaries.
Re-downloaded via `tofu init`.

`infra/infra.env` — contains your real GCP project ID. The `.example` file is
committed; the real file is not.

---

## What we implement in this step

```
Files to create:
  infra/infra.env.example      ← template for user to fill in
  scripts/vault-infra.sh       ← bootstrap functions (login, create-backend)
  .gitignore update            ← ignore terraform/terragrunt generated files

Files to NOT create yet:
  infra/live/terragrunt.hcl    ← needs the bucket to exist first (Plan 03)
  infra/modules/               ← the actual OpenTofu code (Plans 04–07)
```

## Verification for this step

After running `./scripts/vault-infra.sh create-backend`:
```bash
# GCS bucket exists
gcloud storage buckets list --project $GCP_PROJECT_ID | grep $TF_STATE_BUCKET

# Service account exists
gcloud iam service-accounts list --project $GCP_PROJECT_ID | grep opentofu-sa

# SA has the right roles
gcloud projects get-iam-policy $GCP_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:opentofu-sa" \
  --format="table(bindings.role)"
```
