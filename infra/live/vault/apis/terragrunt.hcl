# infra/live/vault/apis/terragrunt.hcl
# Calls the apis module with no extra inputs.
# project_id and region are inherited from the root terragrunt.hcl.
# This module has no dependencies — it runs first in the dependency graph.

terraform {
  source = "../../../modules/apis"
}

include "root" {
  path = find_in_parent_folders()
}
