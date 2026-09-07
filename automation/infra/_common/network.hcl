# ============================================================================
# Wiring for the network module. Included by dev/network/terragrunt.hcl.
#
# WHY this file exists separately from dev/network/terragrunt.hcl:
# the per-environment file stays two `include` blocks long, so adding a second
# environment is a copy of a 6-line file plus its own global-values.yaml --
# never a copy of the module wiring, which would then drift.
# ============================================================================

locals {
  global_vars = yamldecode(file(find_in_parent_folders("global-values.yaml")))
  name_prefix = local.global_vars.global.name_prefix
  aws_region  = local.global_vars.global.aws_region
  vpc_cidr    = local.global_vars.global.vpc_cidr
  az_suffixes = local.global_vars.global.az_suffixes
  common_tags = local.global_vars.global.tags
}

terraform {
  # The double slash matters. It marks where the module root begins, so
  # Terragrunt copies the module directory rather than the whole repo into its
  # cache. Omit it and relative paths inside the module break.
  source = "${get_repo_root()}/automation/infra/modules//network"
}

inputs = {
  name_prefix = local.name_prefix
  aws_region  = local.aws_region
  vpc_cidr    = local.vpc_cidr
  az_suffixes = local.az_suffixes
  tags        = local.common_tags
}
