# Plan 07 — Wiring Everything Together + `run-all`

## What we are building in this step

No new files. This step explains:
1. How the three modules connect to each other via Terragrunt's dependency graph
2. How `terragrunt run-all apply` works
3. The exact sequence Terragrunt uses (and why)
4. The `orchestration script` commands: `plan`, `apply`, `destroy`, `outputs`

---

## The dependency graph

After Plans 03–06, you have this directory structure:

```
infra/live/vault/
├── apis/
│   └── terragrunt.hcl       ← no dependency blocks
├── network/
│   └── terragrunt.hcl       ← dependency "apis"
└── gke/
    └── terragrunt.hcl       ← dependency "apis" + dependency "network"
```

Terragrunt reads all `terragrunt.hcl` files under `infra/live/vault/` and builds
a directed acyclic graph (DAG):

```
   [apis]
     │
     ▼
  [network]
     │
     ▼
   [gke]
```

`apis` → has no dependencies → run first
`network` → depends on apis → run second (after apis finishes)
`gke` → depends on both apis and network → run third (after both finish)

Destroy order is reversed: `gke` → `network` → `apis`. This is critical because
you cannot delete the VPC while the GKE cluster is using the subnet.

---

## `terragrunt run-all` explained

### `run-all plan`

```bash
cd infra/live/vault
terragrunt run-all plan --terragrunt-non-interactive
```

What happens:
1. Terragrunt discovers all modules under the current directory
2. Builds the dependency graph
3. Runs `terragrunt plan` on each module in dependency order
4. For modules with unresolved dependency outputs (network depends on apis, but apis
   hasn't been applied yet), uses `mock_outputs`
5. Prints what each module would create

`--terragrunt-non-interactive` — required in CI and recommended in scripts. Without
it, Terragrunt prompts for confirmation when it discovers new modules.

### `run-all apply`

```bash
cd infra/live/vault
terragrunt run-all apply --terragrunt-non-interactive
```

What happens:
1. Applies `apis` first. Waits for it to complete.
2. Reads `apis` outputs (none in this case).
3. Applies `network`. Waits for it to complete.
4. Reads `network` outputs (vpc_name, subnet_name, pods_range_name, etc.)
5. Passes those outputs as inputs to `gke`.
6. Applies `gke`.

Parallelism: Terragrunt can apply independent modules in parallel. Since `apis` is a
dependency of both `network` and `gke`, they cannot run in parallel with it. But if
you had a module that was independent of all others, it would run concurrently.

### `run-all destroy`

```bash
cd infra/live/vault
terragrunt run-all destroy --terragrunt-non-interactive
```

Reverse order: `gke` → `network` → `apis`.

Why destroy order matters:
- The GKE cluster has nodes with IPs from the subnet. Destroying the subnet before
  the cluster would leave the cluster in an invalid state and the destroy would fail.
- Cloud NAT references Cloud Router. Destroying Cloud Router before Cloud NAT fails.
- The node SA is referenced by the node pool. Destroying the SA before the pool fails.

OpenTofu handles the order within each module automatically (because of implicit
references). Terragrunt handles the order between modules.

---

## The orchestration script commands

These are added to `scripts/vault-infra.sh`:

### `plan` function

```bash
plan() {
  load_config
  check_prerequisites
  cd "$LIVE_DIR"          # cd infra/live/vault
  terragrunt run-all plan \
    --terragrunt-non-interactive
}
```

`cd "$LIVE_DIR"` — Terragrunt discovers modules relative to the current working
directory. Running from `infra/live/vault/` means it discovers apis/, network/, gke/.
Running from `infra/live/` would discover `vault/` as the only entry, which is a
directory not a module.

### `apply` function

```bash
apply() {
  load_config
  check_prerequisites
  cd "$LIVE_DIR"
  terragrunt run-all apply \
    --terragrunt-non-interactive
  _print_outputs
}
```

`_print_outputs` — called after successful apply to show the ingress IP and kubectl
command. Defined as a private helper (prefixed with `_`).

### `destroy` function

```bash
destroy() {
  load_config
  check_prerequisites

  warn "This will destroy ALL GCP resources created by OpenTofu."
  warn "The GCS state bucket will NOT be destroyed."
  echo -n "Type 'yes' to confirm: "
  read -r confirm
  [[ "$confirm" != "yes" ]] && { log "Cancelled."; exit 0; }

  cd "$LIVE_DIR"
  terragrunt run-all destroy \
    --terragrunt-non-interactive
}
```

`read -r confirm` — reads one line from the user. The `-r` flag prevents backslash
escaping. `[[ "$confirm" != "yes" ]]` — if they didn't type exactly "yes", cancel.

Why not destroy the state bucket here? The state bucket holds the state that records
what was just destroyed. If you delete the bucket at the same time as the resources,
OpenTofu loses the ability to verify what was destroyed. Always destroy resources first,
then run `destroy-backend` separately.

### `_print_outputs` helper

```bash
_print_outputs() {
  local ingress_ip
  ingress_ip=$(
    cd "$LIVE_DIR/network" &&
    terragrunt output -raw ingress_static_ip 2>/dev/null \
    || echo "<run 'apply' first>"
  )

  echo "════════════════════════════════════"
  echo "  Ingress IP   : ${ingress_ip}"
  echo ""
  echo "  Configure kubectl:"
  echo "    gcloud container clusters get-credentials ${CLUSTER_NAME} \\"
  echo "      --region ${GCP_REGION} --project ${GCP_PROJECT_ID}"
  echo ""
  echo "  Update DuckDNS → ${ingress_ip}"
  echo "════════════════════════════════════"
}
```

`terragrunt output -raw ingress_static_ip` — reads the value of a specific output
from the network module's state. `-raw` prints just the value without quotes or
formatting. `2>/dev/null` — suppresses any error messages (e.g. if the module hasn't
been applied yet).

### `outputs` function

```bash
outputs() {
  load_config
  check_prerequisites
  _print_outputs
}
```

Calls the helper directly. Useful for retrieving the ingress IP after the cluster is
already running (without running a full apply again).

### `destroy_backend_resources` function

```bash
destroy_backend_resources() {
  load_config
  local SA_EMAIL="${TOFU_SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

  warn "Only run this AFTER 'destroy' has completed successfully."
  echo -n "Type 'yes' to confirm: "
  read -r confirm
  [[ "$confirm" != "yes" ]] && { log "Cancelled."; exit 0; }

  gcloud storage rm -r "gs://${TF_STATE_BUCKET}" --project="$GCP_PROJECT_ID"
  gcloud iam service-accounts delete "$SA_EMAIL" \
    --project="$GCP_PROJECT_ID" --quiet
}
```

`gcloud storage rm -r` — deletes all objects in the bucket AND the bucket itself.
`-r` = recursive. Without `-r`, the command fails if the bucket is non-empty.

---

## End-to-end flow from zero to running cluster

```
Day 1 — first time setup:

  Step 1: Copy config
    cp infra/infra.env.example infra/infra.env
    # edit infra/infra.env — set GCP_PROJECT_ID

  Step 2: Login
    ./scripts/vault-infra.sh login
    # Browser opens, sign in with your Google account
    # gcloud auth application-default login creates ~/.config/gcloud/...credentials.json

  Step 3: Create backend
    ./scripts/vault-infra.sh create-backend
    # gcloud creates gs://vault-tofu-state bucket
    # gcloud creates opentofu-sa service account
    # gcloud grants 6 IAM roles

  Step 4: Plan
    ./scripts/vault-infra.sh plan
    # terragrunt run-all plan
    # Shows: 5 APIs, 1 VPC, 1 subnet, 1 router, 1 NAT, 1 IP, 4 firewall rules,
    #         1 SA, 5 IAM bindings, 1 cluster, 1 node pool
    # Total: ~20 resources to create

  Step 5: Apply
    ./scripts/vault-infra.sh apply
    # Takes ~10-15 minutes (GKE cluster creation is the slow step)
    # Prints: Ingress IP, kubectl command

  Step 6: Configure kubectl
    gcloud container clusters get-credentials vault-cluster \
      --region asia-south1 --project $GCP_PROJECT_ID

  Step 7: Update DuckDNS
    # Go to duckdns.org
    # Update A record for vaultpraja.duckdns.org → the printed ingress IP

  Step 8: Deploy the application
    # Use vault-automation/ scripts as before (Helm charts, etc.)
    # The cluster is ready — vault-automation does not change
```

---

## What Terragrunt puts in `.terragrunt-cache/`

After running `terragrunt apply`, the directory looks like:

```
infra/live/vault/network/.terragrunt-cache/
└── <hash>/
    └── <hash>/
        ├── main.tf           ← copied from modules/network/main.tf
        ├── variables.tf      ← copied from modules/network/variables.tf
        ├── outputs.tf        ← copied from modules/network/outputs.tf
        ├── backend.tf        ← GENERATED by Terragrunt (remote_state block)
        ├── provider.tf       ← GENERATED by Terragrunt (generate "provider" block)
        └── .terraform/       ← OpenTofu's provider downloads
```

`.terragrunt-cache/` is gitignored because:
- It contains generated files that should not be committed
- It is large (provider binaries are 50–100 MB each)
- It is regenerated automatically on every Terragrunt run

---

## Verification for this complete step

After `./scripts/vault-infra.sh apply`:

```bash
# All modules applied — check state files exist
gsutil ls gs://$TF_STATE_BUCKET/vault/
# Expected:
#   gs://vault-tofu-state/vault/apis/
#   gs://vault-tofu-state/vault/network/
#   gs://vault-tofu-state/vault/gke/

# Cluster is RUNNING
gcloud container clusters list --project $GCP_PROJECT_ID
# STATUS = RUNNING

# Nodes are Ready
kubectl get nodes
# STATUS = Ready (2 nodes)

# Static IP is IN_USE
gcloud compute addresses list --region asia-south1 --project $GCP_PROJECT_ID
# STATUS = IN_USE  (assigned to the ingress-nginx LB after Helm deploy)
# NOTE: STATUS = RESERVED until ingress-nginx is deployed via Helm
```
