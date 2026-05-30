# infra/live/vault/gke/terragrunt.hcl
# Calls the gke module.  Depends on both apis (ordering) and network (outputs).

terraform {
  source = "../../../modules/gke"
}

include "root" {
  path = find_in_parent_folders()
}

# ── Dependency: apis ───────────────────────────────────────────────────────────
# Ordering only — ensures APIs are enabled before the cluster is created.

dependency "apis" {
  config_path = "../apis"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs                            = {}
}

# ── Dependency: network ────────────────────────────────────────────────────────
# Reads the network module's outputs and passes them as inputs to the gke module.
# This is how the GKE cluster knows which VPC, subnet, and IP ranges to use.
#
# mock_outputs are used when running 'plan' before the network module has been
# applied.  They are placeholder values that let OpenTofu validate the GKE
# module's configuration without real network outputs existing yet.
# mock_outputs_allowed_terraform_commands restricts mocks to plan/validate only —
# an actual apply will always read real outputs.

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

# ── Inputs ─────────────────────────────────────────────────────────────────────

inputs = {
  # From infra/infra.env (via exported environment variables)
  cluster_name    = get_env("CLUSTER_NAME", "vault-cluster")
  node_pool_name  = get_env("NODE_POOL_NAME", "vault-nodes")
  node_sa_name    = "vault-gke-node-sa"
  machine_type    = get_env("MACHINE_TYPE", "e2-standard-2")
  node_count      = tonumber(get_env("NODE_COUNT", "2"))
  disk_size_gb    = tonumber(get_env("DISK_SIZE_GB", "50"))
  k8s_version     = get_env("K8S_VERSION", "1.30")
  node_tag        = "gke-node"

  # From the network module outputs
  network_name        = dependency.network.outputs.vpc_name
  subnet_name         = dependency.network.outputs.subnet_name
  pods_range_name     = dependency.network.outputs.pods_range_name
  services_range_name = dependency.network.outputs.services_range_name
}
