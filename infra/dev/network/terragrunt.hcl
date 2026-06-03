terraform {
  source = "../../modules/network"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependencies {
  paths = ["../apis"]
}

inputs = {
  subnet_cidr         = "10.0.0.0/24"
  pods_range_name     = "pods"
  pods_cidr           = "10.1.0.0/16"
  services_range_name = "services"
  services_cidr       = "10.2.0.0/20"
}
