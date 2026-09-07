# ============================================================================
# Wiring for the eks module. Included by dev/eks/terragrunt.hcl.
# ============================================================================

locals {
  global_vars = yamldecode(file(find_in_parent_folders("global-values.yaml")))
  g           = local.global_vars.global
}

terraform {
  source = "${get_repo_root()}/automation/infra/modules//eks"
}

# `dependency` does two things: it orders the applies (network before eks), and
# it reads the network's outputs out of its state file.
dependency "network" {
  config_path = "../network"

  # mock_outputs let `terragrunt plan` on the whole stack work BEFORE the
  # network has ever been applied. Without them, planning eks fails because
  # the network state does not exist yet -- so you could never review the
  # full plan up front, only apply blindly one component at a time.
  mock_outputs = {
    vpc_id            = "vpc-00000000000000000"
    public_subnet_ids = ["subnet-00000000000000000", "subnet-11111111111111111"]
  }

  # Prefer real state once it exists, fall back to mocks per-key while it
  # does not. Without "shallow", a single missing key discards the whole
  # real output set.
  mock_outputs_merge_strategy_with_state = "shallow"
}

inputs = {
  name_prefix = local.g.name_prefix
  vpc_id      = dependency.network.outputs.vpc_id
  subnet_ids  = dependency.network.outputs.public_subnet_ids

  cluster_version = local.g.eks_cluster_version

  node_instance_type = local.g.eks_node_instance_type
  node_capacity_type = local.g.eks_node_capacity_type
  node_count_desired = local.g.eks_node_count_desired
  node_count_min     = local.g.eks_node_count_min
  node_count_max     = local.g.eks_node_count_max
  node_disk_size_gb  = local.g.eks_node_disk_size_gb

  endpoint_public_access = local.g.eks_endpoint_public_access
  public_access_cidrs    = local.g.eks_public_access_cidrs

  enable_ebs_csi_driver = local.g.eks_enable_ebs_csi_driver

  # try(): these keys were added after the first version of
  # global-values.yaml, so an older copy of that file must not break the plan.
  cluster_log_types = try(local.g.eks_cluster_log_types, [])

  tags = local.g.tags
}
