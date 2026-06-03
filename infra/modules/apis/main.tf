resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",              # VPC, subnet, firewall, Cloud Router, Cloud NAT, static IP
    "container.googleapis.com",            # GKE cluster and node pools
    "iam.googleapis.com",                  # Service accounts and IAM bindings
    "cloudresourcemanager.googleapis.com", # Required by many GCP provider resource operations
    "servicenetworking.googleapis.com",    # VPC-native (alias IP) networking for GKE
  ])

  project = var.project_id
  service = each.value

  # Do not disable the API when this resource is destroyed.
  # Other workloads in the same project may depend on the same APIs.
  disable_on_destroy = false
}
