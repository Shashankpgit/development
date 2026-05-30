# infra/live/terragrunt.hcl
# Root Terragrunt config — inherited by every module under infra/live/vault/.
#
# This file does three things:
#   1. Defines remote state — every module gets its own GCS key automatically.
#   2. Injects provider.tf — every module gets the google provider without
#      having to declare it themselves.
#   3. Passes project_id and region as inputs to every module.
#
# All values are read from environment variables set by infra/infra.env.
# The shell script (scripts/vault-infra.sh) sources that file before running
# any terragrunt command, so the variables are always in scope.

locals {
  project_id = get_env("GCP_PROJECT_ID")
  region     = get_env("GCP_REGION")
  # TF_STATE_BUCKET defaults to "vault-tofu-state" if the env var is unset.
  # In normal use it is always set by infra/infra.env.
  bucket     = get_env("TF_STATE_BUCKET", "vault-tofu-state")
}

# ── Remote state ───────────────────────────────────────────────────────────────
# Terragrunt auto-generates a backend.tf in each module's working directory.
# path_relative_to_include() returns the module's path relative to this file,
# giving each module a unique key in the GCS bucket:
#
#   live/vault/apis/    → gs://<bucket>/live/vault/apis/terraform.tfstate
#   live/vault/network/ → gs://<bucket>/live/vault/network/terraform.tfstate
#   live/vault/gke/     → gs://<bucket>/live/vault/gke/terraform.tfstate

remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = local.bucket
    prefix = path_relative_to_include()
  }
}

# ── Provider injection ─────────────────────────────────────────────────────────
# Terragrunt writes provider.tf into each module's .terragrunt-cache directory
# before running tofu.  Modules do not need their own provider.tf.

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "~> 5.0"
        }
      }
      required_version = ">= 1.6"
    }

    provider "google" {
      project = "${local.project_id}"
      region  = "${local.region}"
    }
  EOF
}

# ── Shared inputs ──────────────────────────────────────────────────────────────
# All modules receive project_id and region automatically.
# Module-specific inputs are added in each module's own terragrunt.hcl.

inputs = {
  project_id = local.project_id
  region     = local.region
}
