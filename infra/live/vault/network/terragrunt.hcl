# infra/live/vault/network/terragrunt.hcl
# Calls the network module with values from infra/infra.env.
# Depends on apis to ensure GCP APIs are enabled before any network resource
# is created.

terraform {
  source = "../../../modules/network"
}

include "root" {
  path = find_in_parent_folders()
}

# ── Dependency: apis ───────────────────────────────────────────────────────────
# The apis module has no outputs — this dependency is for ordering only.
# Terragrunt will apply apis before network.
# mock_outputs are provided so 'plan' can run without apis being applied first.

dependency "apis" {
  config_path = "../apis"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs                            = {}
}

# ── Inputs ─────────────────────────────────────────────────────────────────────
# get_env("VAR", "default") reads from the environment (set by infra/infra.env).
# The second argument is the fallback used when running terragrunt directly
# outside the vault-infra.sh script.

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
