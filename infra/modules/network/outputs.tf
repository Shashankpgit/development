# infra/modules/network/outputs.tf
# These outputs are consumed by the gke module via:
#   dependency.network.outputs.<name>

output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "Self-link of the VPC (used by GKE cluster's network argument)"
  value       = google_compute_network.vpc.self_link
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_self_link" {
  description = "Self-link of the subnet (used by GKE cluster's subnetwork argument)"
  value       = google_compute_subnetwork.subnet.self_link
}

output "pods_range_name" {
  description = "Name of the pods secondary IP range (passed to GKE ip_allocation_policy)"
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "Name of the services secondary IP range (passed to GKE ip_allocation_policy)"
  value       = var.services_range_name
}

output "ingress_static_ip" {
  description = "Reserved external IP for the ingress-nginx LoadBalancer. Set this in DuckDNS once."
  value       = google_compute_address.ingress_ip.address
}
