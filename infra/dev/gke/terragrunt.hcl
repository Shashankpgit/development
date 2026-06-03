terraform {
  source = "../../modules/gke"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependencies {
  paths = ["../apis"]
}

dependency "network" {
  config_path = "../network"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_name            = "mock-vpc"
    subnet_name         = "mock-subnet"
    pods_range_name     = "pods"
    services_range_name = "services"
    node_tag            = "mock-node-tag"
    ingress_static_ip   = "0.0.0.0"
  }
}

inputs = {
  # Network values — read from network module outputs
  vpc_name            = dependency.network.outputs.vpc_name
  subnet_name         = dependency.network.outputs.subnet_name
  pods_range_name     = dependency.network.outputs.pods_range_name
  services_range_name = dependency.network.outputs.services_range_name
  node_tag            = dependency.network.outputs.node_tag

  # Node pool configuration — values chosen to stay within free tier quotas
  machine_type = "e2-medium"
  node_count   = 1
  disk_type    = "pd-standard"
  disk_size_gb = 30
}
