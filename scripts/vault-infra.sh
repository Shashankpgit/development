#!/usr/bin/env bash
# scripts/vault-infra.sh
# Orchestrates OpenTofu + Terragrunt for the vault GCP infrastructure.
# All configuration is read from infra/infra.env — edit that file, not this one.
#
# Usage:
#   ./scripts/vault-infra.sh <command>
#
# Commands:
#   login            Authenticate with GCP (gcloud auth + application-default)
#   create-backend   Create GCS state bucket + OpenTofu SA (run once before anything else)
#   plan             Show what OpenTofu will create / change / destroy
#   apply            Create or update all GCP infrastructure
#   destroy          Destroy all GCP infrastructure (keeps state bucket)
#   destroy-backend  Delete the GCS state bucket + OpenTofu SA (run after destroy)
#   outputs          Print the ingress static IP and kubectl credentials command

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_ENV="$REPO_ROOT/infra/infra.env"
LIVE_DIR="$REPO_ROOT/infra/live/vault"

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[vault-infra]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }
step()  { echo -e "\n${BOLD}${BLUE}▶ $*${NC}"; }

# ── load_config ────────────────────────────────────────────────────────────────
# Sources infra/infra.env so every exported variable is available to this
# script AND to child processes (gcloud, terragrunt, tofu) as environment vars.
load_config() {
  if [[ ! -f "$INFRA_ENV" ]]; then
    error "Config file not found: $INFRA_ENV
Copy infra/infra.env.example to infra/infra.env and fill in your GCP project ID."
  fi
  # shellcheck source=/dev/null
  source "$INFRA_ENV"
  log "Config loaded"
  log "  Project : ${GCP_PROJECT_ID}"
  log "  Region  : ${GCP_REGION}"
  log "  Cluster : ${CLUSTER_NAME}"
  log "  Bucket  : gs://${TF_STATE_BUCKET}"
}

# ── check_prerequisites ────────────────────────────────────────────────────────
# Verifies that gcloud, tofu, and terragrunt are installed before running any
# command that needs them.
check_prerequisites() {
  step "Checking prerequisites"
  local missing=0
  for cmd in gcloud tofu terragrunt; do
    if command -v "$cmd" &>/dev/null; then
      log "  ✓ $cmd  ($(command -v "$cmd"))"
    else
      warn "  ✗ $cmd  — not found in PATH"
      missing=$((missing + 1))
    fi
  done
  if [[ $missing -gt 0 ]]; then
    error "$missing required tool(s) missing.
Install guides:
  tofu        → https://opentofu.org/docs/intro/install/
  terragrunt  → https://terragrunt.gruntwork.io/docs/getting-started/install/
  gcloud      → https://cloud.google.com/sdk/docs/install"
  fi
  log "All prerequisites satisfied"
}

# ── login ──────────────────────────────────────────────────────────────────────
# Runs interactive gcloud login flows.  Must be called once before the first
# create-backend / apply.  Safe to re-run.
login() {
  step "Authenticating with GCP"
  load_config

  log "Step 1/3 — browser login (gcloud auth login)"
  gcloud auth login

  log "Step 2/3 — set active project to ${GCP_PROJECT_ID}"
  gcloud config set project "$GCP_PROJECT_ID"

  log "Step 3/3 — application-default credentials (used by OpenTofu)"
  gcloud auth application-default login

  log "Active account : $(gcloud config get-value account)"
  log "Active project : $(gcloud config get-value project)"
}

# ── create_backend_resources ───────────────────────────────────────────────────
# Creates the GCS state bucket and the OpenTofu service account using gcloud.
# This must run BEFORE 'plan' or 'apply' because OpenTofu needs the bucket to
# store its state.  It is idempotent — safe to run multiple times.
#
# After this function, TF_STATE_BUCKET (already set from infra.env) is the
# bucket Terragrunt will use via get_env("TF_STATE_BUCKET") in terragrunt.hcl.
# No extra wiring is required.
create_backend_resources() {
  step "Creating backend resources"
  load_config

  local SA_EMAIL="${TOFU_SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

  # ── 1. GCS state bucket ─────────────────────────────────────────────────────
  log "── GCS state bucket ──────────────────────────────────────"
  if gcloud storage buckets describe "gs://${TF_STATE_BUCKET}" \
       --project="$GCP_PROJECT_ID" &>/dev/null; then
    warn "Bucket gs://${TF_STATE_BUCKET} already exists — skipping creation"
  else
    log "Creating gs://${TF_STATE_BUCKET} in region ${GCP_REGION}"
    gcloud storage buckets create "gs://${TF_STATE_BUCKET}" \
      --project="$GCP_PROJECT_ID" \
      --location="$GCP_REGION" \
      --uniform-bucket-level-access
    log "Bucket created"
  fi

  # Versioning lets us recover from accidental state corruption by restoring
  # a previous version of the state file from GCS object history.
  log "Enabling versioning on bucket"
  gcloud storage buckets update "gs://${TF_STATE_BUCKET}" --versioning
  log "Versioning enabled"

  # ── 2. OpenTofu service account ─────────────────────────────────────────────
  log "── OpenTofu service account ──────────────────────────────"
  if gcloud iam service-accounts describe "$SA_EMAIL" \
       --project="$GCP_PROJECT_ID" &>/dev/null; then
    warn "Service account ${SA_EMAIL} already exists — skipping creation"
  else
    log "Creating service account: ${TOFU_SA_NAME}"
    gcloud iam service-accounts create "$TOFU_SA_NAME" \
      --project="$GCP_PROJECT_ID" \
      --display-name="OpenTofu Infrastructure Automation"
    log "Service account created"
  fi

  # ── 3. Minimum IAM roles for the SA ─────────────────────────────────────────
  # These are the minimum roles needed to create the resources in this IaC:
  #   container.admin          — create/manage GKE clusters and node pools
  #   compute.admin            — create/manage VPC, subnet, firewall, NAT, IPs
  #   iam.serviceAccountAdmin  — create the GKE node service account
  #   iam.serviceAccountUser   — attach the node SA to the node pool
  #   storage.admin            — read/write the state bucket
  #   serviceusage.serviceUsageAdmin — enable GCP APIs (Phase 19.3)
  log "── Granting IAM roles ────────────────────────────────────"
  local roles=(
    "roles/container.admin"
    "roles/compute.admin"
    "roles/iam.serviceAccountAdmin"
    "roles/iam.serviceAccountUser"
    "roles/storage.admin"
    "roles/serviceusage.serviceUsageAdmin"
  )
  for role in "${roles[@]}"; do
    log "  Granting ${role}"
    gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="$role" \
      --quiet
  done

  # ── 4. Bucket-level access for the SA ───────────────────────────────────────
  log "Granting objectAdmin on state bucket to SA"
  gcloud storage buckets add-iam-policy-binding "gs://${TF_STATE_BUCKET}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.objectAdmin"

  # ── Summary ─────────────────────────────────────────────────────────────────
  step "Backend resources ready"
  echo ""
  echo "  State bucket : gs://${TF_STATE_BUCKET}"
  echo "  OpenTofu SA  : ${SA_EMAIL}"
  echo ""
  echo "  Next step:"
  echo "    $(basename "$0") plan    ← review what will be created"
  echo "    $(basename "$0") apply   ← build all GCP infrastructure"
  echo ""
}

# ── plan ───────────────────────────────────────────────────────────────────────
# Runs 'terragrunt run-all plan' across all three modules (apis → network → gke).
# Does NOT change anything in GCP.  Always run this before apply.
plan() {
  step "Planning infrastructure (no changes will be made)"
  load_config
  check_prerequisites
  cd "$LIVE_DIR"
  terragrunt run-all plan \
    --terragrunt-non-interactive \
    --terragrunt-include-dir "$(pwd)"
}

# ── apply ──────────────────────────────────────────────────────────────────────
# Runs 'terragrunt run-all apply' in dependency order: apis → network → gke.
# Prints outputs (ingress IP + kubectl command) on success.
apply() {
  step "Applying infrastructure"
  load_config
  check_prerequisites
  cd "$LIVE_DIR"
  terragrunt run-all apply \
    --terragrunt-non-interactive \
    --terragrunt-include-dir "$(pwd)"
  _print_outputs
}

# ── destroy ────────────────────────────────────────────────────────────────────
# Destroys all GCP resources in reverse dependency order: gke → network → apis.
# The GCS state bucket is NOT destroyed — it holds the state needed to track
# what was just destroyed.  Run 'destroy-backend' separately if you want to
# remove the bucket too.
destroy() {
  step "Destroying infrastructure"
  load_config
  check_prerequisites

  echo ""
  warn "This will destroy ALL GCP resources created by OpenTofu:"
  warn "  GKE cluster, node pool, VPC, subnet, NAT, firewall rules, static IP"
  warn "The GCS state bucket will NOT be destroyed."
  echo ""
  echo -n "Type 'yes' to confirm destruction: "
  read -r confirm
  [[ "$confirm" != "yes" ]] && { log "Cancelled."; exit 0; }

  cd "$LIVE_DIR"
  terragrunt run-all destroy \
    --terragrunt-non-interactive \
    --terragrunt-include-dir "$(pwd)"
  log "All infrastructure destroyed"
}

# ── destroy_backend_resources ──────────────────────────────────────────────────
# Removes the GCS state bucket and the OpenTofu service account.
# Only run this AFTER 'destroy' has completed successfully — the bucket holds
# the state used to track what was destroyed.
destroy_backend_resources() {
  step "Destroying backend resources"
  load_config

  local SA_EMAIL="${TOFU_SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

  echo ""
  warn "This will permanently delete:"
  warn "  gs://${TF_STATE_BUCKET}  (all state files, all versions)"
  warn "  ${SA_EMAIL}"
  warn "Only run this AFTER 'destroy' has completed."
  echo ""
  echo -n "Type 'yes' to confirm: "
  read -r confirm
  [[ "$confirm" != "yes" ]] && { log "Cancelled."; exit 0; }

  log "Deleting all objects and bucket: gs://${TF_STATE_BUCKET}"
  gcloud storage rm -r "gs://${TF_STATE_BUCKET}" \
    --project="$GCP_PROJECT_ID"
  log "Bucket deleted"

  log "Deleting service account: ${SA_EMAIL}"
  gcloud iam service-accounts delete "$SA_EMAIL" \
    --project="$GCP_PROJECT_ID" \
    --quiet
  log "Service account deleted"

  log "Backend resources removed"
}

# ── outputs ────────────────────────────────────────────────────────────────────
# Reads outputs from the applied state and prints the ingress IP and the
# exact gcloud command to configure kubectl.
outputs() {
  step "Fetching infrastructure outputs"
  load_config
  check_prerequisites
  _print_outputs
}

# ── _print_outputs (internal) ──────────────────────────────────────────────────
_print_outputs() {
  local ingress_ip
  ingress_ip=$(
    cd "$LIVE_DIR/network" &&
    terragrunt output -raw ingress_static_ip 2>/dev/null \
    || echo "<run 'apply' first>"
  )

  local cluster_name="${CLUSTER_NAME:-vault-cluster}"
  local region="${GCP_REGION:-asia-south1}"
  local project="${GCP_PROJECT_ID:-<project>}"

  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  VAULT INFRASTRUCTURE OUTPUTS"
  echo "════════════════════════════════════════════════════════════"
  echo "  Cluster      : ${cluster_name}"
  echo "  Region       : ${region}"
  echo "  Ingress IP   : ${ingress_ip}"
  echo ""
  echo "  Configure kubectl:"
  echo "    gcloud container clusters get-credentials ${cluster_name} \\"
  echo "      --region ${region} --project ${project}"
  echo ""
  echo "  Update DuckDNS A record → ${ingress_ip}"
  echo "════════════════════════════════════════════════════════════"
  echo ""
}

# ── usage ──────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF

${BOLD}vault-infra.sh${NC} — GCP infrastructure automation via OpenTofu + Terragrunt

${BOLD}Usage:${NC}
  $(basename "$0") <command>

${BOLD}Commands:${NC}
  login             Authenticate with GCP (gcloud auth + application-default)
  create-backend    Create GCS state bucket + OpenTofu SA  [run once]
  plan              Preview changes without applying them
  apply             Create or update all GCP infrastructure
  destroy           Destroy all GCP infrastructure  (prompts for confirmation)
  destroy-backend   Remove the state bucket + OpenTofu SA  [run after destroy]
  outputs           Print the ingress IP and kubectl credentials command

${BOLD}Config file:${NC}
  infra/infra.env   (copy from infra/infra.env.example and edit)

${BOLD}First-time workflow:${NC}
  1.  cp infra/infra.env.example infra/infra.env
  2.  # Edit infra/infra.env — set GCP_PROJECT_ID at minimum
  3.  $(basename "$0") login
  4.  $(basename "$0") create-backend
  5.  $(basename "$0") plan
  6.  $(basename "$0") apply
  7.  $(basename "$0") outputs          ← copy ingress IP → update DuckDNS

EOF
}

# ── entrypoint ─────────────────────────────────────────────────────────────────
case "${1:-}" in
  login)            login ;;
  create-backend)   create_backend_resources ;;
  plan)             plan ;;
  apply)            apply ;;
  destroy)          destroy ;;
  destroy-backend)  destroy_backend_resources ;;
  outputs)          outputs ;;
  help|--help|-h)   usage ;;
  *)
    error "Unknown command: '${1:-}'
Run '$(basename "$0") help' for usage."
    ;;
esac
