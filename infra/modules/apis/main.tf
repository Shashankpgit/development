# infra/modules/apis/main.tf
# Enables the GCP project APIs that every other module depends on.
#
# Why this is a separate module:
#   If you try to create a GKE cluster before container.googleapis.com is
#   enabled, GCP returns an opaque 403.  By putting API enablement in its own
#   module with no dependencies, Terragrunt applies it first and the subsequent
#   modules never hit that error.
#
# for_each pattern:
#   Instead of writing one google_project_service resource per API, we use
#   for_each = toset([...]).  OpenTofu creates one resource instance per API,
#   all managed together.  The instance key is the API string itself, so the
#   state key looks like:
#     google_project_service.apis["compute.googleapis.com"]

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",               # VPC, subnet, firewall, Cloud Router, Cloud NAT, static IP
    "container.googleapis.com",             # GKE cluster and node pools
    "iam.googleapis.com",                   # Service accounts and IAM bindings
    "cloudresourcemanager.googleapis.com",  # Required by many GCP provider resources for project lookups
    "servicenetworking.googleapis.com",     # VPC-native (alias IP) networking for GKE
  ])

  project = var.project_id
  service = each.value

  # Do NOT disable the API when this resource is destroyed.
  # The project may have other workloads depending on the same APIs.
  # Disabling an API that another team's resource depends on causes outages.
  disable_on_destroy = false
}
