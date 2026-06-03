# Vault Application — Deployment Guide

This file is the step-by-step reference for deploying the full vault infrastructure
from scratch. Follow the steps in order. Each step lists exactly what to run and
how to verify it worked before moving to the next.

---

## Prerequisites

These tools must be installed on your machine before running any command.
Check what you already have:

```bash
gcloud --version
tofu --version
terragrunt --version
```

### Install gcloud (Google Cloud CLI)

```bash
# Linux
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh

# Restart terminal, then verify
gcloud --version
```

### Install OpenTofu

```bash
# Download the latest release (check https://opentofu.org/docs/intro/install/)
curl -LO https://github.com/opentofu/opentofu/releases/download/v1.9.0/tofu_1.9.0_linux_amd64.zip
unzip tofu_1.9.0_linux_amd64.zip
sudo mv tofu /usr/local/bin/
tofu --version
```

### Install Terragrunt

```bash
# Download the latest release (check https://github.com/gruntwork-io/terragrunt/releases)
curl -LO https://github.com/gruntwork-io/terragrunt/releases/download/v0.67.0/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
terragrunt --version
```

---

## Step 1 — Authenticate with GCP

You need to authenticate twice — once for `gcloud` commands, once for OpenTofu.

```bash
# 1. Authenticate gcloud (opens browser)
gcloud auth login

# 2. Set the active project
gcloud config set project learning-gcp-496710

# 3. Create application-default credentials (used by OpenTofu when calling GCP APIs)
gcloud auth application-default login
```

**Verify:**
```bash
gcloud config get-value account    # should show your email
gcloud config get-value project    # should show learning-gcp-496710
```

---

## Step 2 — Create the Backend Storage (Bootstrap)

This is the first infrastructure step. It creates the GCS bucket that OpenTofu
uses to store its state files and generates the config file that all Terragrunt
modules will read.

**This step uses `gcloud` directly — not OpenTofu — because OpenTofu needs the
bucket to exist before it can run.**

### What gets created

| Resource | Name | Purpose |
|---|---|---|
| GCS bucket | `dev-vault-backend-496710` | Stores OpenTofu state files |
| `infra/dev/backend.hcl` | (generated file) | Config read by all Terragrunt modules |

### Check the config before running

Open `infra/config.env` and confirm the values are correct:

```bash
cat infra/config.env
```

Expected output:
```bash
export GCP_PROJECT_ID="learning-gcp-496710"
export GCP_REGION="asia-south1"
export ENV_NAME="dev"
export APP_NAME="vault"
```

If you are deploying a different environment (e.g. prod), change `ENV_NAME="prod"`
before running the next command.

### Run the bootstrap script

```bash
./scripts/bootstrap.sh          # "create" is the default command
# or explicitly:
./scripts/bootstrap.sh create
```

The script will:
1. Read `infra/config.env`
2. Create bucket `gs://learning-gcp-496710-dev-tofu-state` in `asia-south1`
3. Enable versioning on the bucket (protects against state corruption)
4. Write `infra/dev/backend.hcl` with all common values for Terragrunt

**Expected output (last few lines):**
```
════════════════════════════════════════════════════════════════════
  Bootstrap complete for environment: dev
════════════════════════════════════════════════════════════════════
  State bucket : gs://learning-gcp-496710-dev-tofu-state
  Backend file : infra/dev/backend.hcl

  Resource names that will be created:
    VPC         → dev-vault-vpc
    Subnet      → dev-vault-subnet
    Router      → dev-vault-router
    NAT         → dev-vault-nat
    Cluster     → dev-vault-cluster
    Node pool   → dev-vault-nodes
```

### Verify it worked

```bash
# 1. Bucket exists
gcloud storage buckets list --project learning-gcp-496710 | grep tofu-state

# 2. Versioning is enabled
gcloud storage buckets describe gs://learning-gcp-496710-dev-tofu-state \
  | grep versioning

# 3. backend.hcl was generated
cat infra/dev/backend.hcl
```

**Expected `backend.hcl` content:**
```hcl
locals {
  project_id   = "learning-gcp-496710"
  region       = "asia-south1"
  env_name     = "dev"
  app_name     = "vault"
  state_bucket = "dev-vault-backend-496710"
}
```

If all three checks pass, Step 2 is complete.

---

## Step 3 — Root Terragrunt Config

File: `infra/dev/terragrunt.hcl`

This file is inherited by every module under `infra/dev/`. No commands to run —
it is picked up automatically when any module runs `terragrunt apply`.

What it does:
- Reads `infra/dev/backend.hcl` (written by bootstrap) for project_id, region, env_name, app_name, state_bucket
- Configures GCS remote state — each module gets its own key in the bucket
- Generates `provider.tf` into every module automatically
- Passes project_id, region, env_name, app_name as shared inputs to every module

**Verify** (once a module exists):
```bash
cd infra/dev/apis
terragrunt init
# Should connect to gs://dev-vault-backend-496710 without errors
```

---

## Step 4 — APIs Module

> Not yet implemented. Documented in `docs/infra-plan/04-plan-apis-module.md`.

---

## Step 5 — Network Module

> Not yet implemented. Documented in `docs/infra-plan/05-plan-network-module.md`.

---

## Step 6 — GKE Module

> Not yet implemented. Documented in `docs/infra-plan/06-plan-gke-module.md`.

---

## Step 7 — Deploy the Application

> Not yet implemented. Refer to `vault-automation/` for Helm deployments.

---

## Teardown (destroy everything)

When you want to delete all infrastructure:

```bash
# 1. Destroy all GCP resources (cluster, VPC, firewall rules, etc.)
#    [command will be added when orchestration script is built]

# 2. Delete the state bucket ONLY after step 1 is confirmed complete
./scripts/bootstrap.sh delete
```

> **Important:** always destroy the GCP infrastructure before deleting the backend.
> The bucket holds the state that tracks what was created. Delete it first and
> OpenTofu loses the ability to clean up the resources automatically.

---

## Quick reference — resource naming

All resources follow the pattern `{env}-{app}-{resource}`.
With `ENV_NAME=dev` and `APP_NAME=vault`:

| Resource type | Name |
|---|---|
| GCS state bucket | `dev-vault-backend-496710` |
| VPC | `dev-vault-vpc` |
| Subnet | `dev-vault-subnet` |
| Cloud Router | `dev-vault-router` |
| Cloud NAT | `dev-vault-nat` |
| Static IP | `dev-vault-ingress-ip` |
| GKE cluster | `dev-vault-cluster` |
| Node pool | `dev-vault-nodes` |
| Node service account | `dev-vault-node-sa` |

---

## Key files reference

| File | Purpose |
|---|---|
| `infra/config.env` | Edit this — project ID, region, env name, app name |
| `scripts/bootstrap.sh` | Run once to create state bucket and generate backend.hcl |
| `infra/dev/backend.hcl` | Generated by bootstrap — read by all Terragrunt modules |
| `infra/dev/terragrunt.hcl` | Root Terragrunt config for the dev environment |
| `infra/modules/` | OpenTofu module code (apis, network, gke) |
| `infra/dev/apis/` | Terragrunt config that calls the apis module |
| `infra/dev/network/` | Terragrunt config that calls the network module |
| `infra/dev/gke/` | Terragrunt config that calls the gke module |
| `docs/infra-plan/` | Detailed implementation plans (block-by-block explanations) |
| `docs/networking/` | Networking concepts reference (VPC, NAT, firewall, etc.) |
