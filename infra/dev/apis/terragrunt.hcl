# Calls the apis module.
# No extra inputs needed — project_id, region, env_name, app_name
# are all inherited from infra/dev/terragrunt.hcl.

terraform {
  source = "../../modules/apis"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}
