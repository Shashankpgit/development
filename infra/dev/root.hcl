# infra/dev/terragrunt.hcl
# Root Terragrunt config for the dev environment.
# Every module under infra/dev/ inherits this file via:
#   include "root" { path = find_in_parent_folders() }
#
# This file does three things:
#   1. Reads backend.hcl (written by bootstrap.sh) for all common values
#   2. Configures GCS remote state — each module gets its own key in the bucket
#   3. Generates provider.tf into every module so they don't declare it themselves

# ── Read the values written by bootstrap.sh ────────────────────────────────────
# backend.hcl contains: project_id, region, env_name, app_name, state_bucket
locals {
  # get_repo_root() returns the absolute path to the git repo root — reliable
  # regardless of which child module is currently running.
  # get_env("ENV_NAME", "dev") reads the ENV_NAME exported by config.env.
  cfg = read_terragrunt_config(
    "${get_repo_root()}/infra/${get_env("ENV_NAME", "dev")}/backend.hcl"
  )

  project_id   = local.cfg.locals.project_id
  region       = local.cfg.locals.region
  env_name     = local.cfg.locals.env_name
  app_name     = local.cfg.locals.app_name
  state_bucket = local.cfg.locals.state_bucket
}

# ── Remote state ───────────────────────────────────────────────────────────────
# Terragrunt generates a backend.tf in each module before tofu runs.
# path_relative_to_include() gives each module a unique key in the bucket:
#   apis/    → gs://dev-vault-backend-496710/apis/terraform.tfstate
#   network/ → gs://dev-vault-backend-496710/network/terraform.tfstate
#   gke/     → gs://dev-vault-backend-496710/gke/terraform.tfstate
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = local.state_bucket
    prefix = path_relative_to_include()
  }
}

# ── Provider injection ─────────────────────────────────────────────────────────
# Terragrunt writes provider.tf into each module's working directory before
# running tofu. Modules do not need to declare the provider themselves.
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
# All modules receive these automatically without declaring them in each
# module's own terragrunt.hcl.
inputs = {
  project_id = local.project_id
  region     = local.region
  env_name   = local.env_name
  app_name   = local.app_name
}
