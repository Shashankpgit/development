output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}

output "pods_range_name" {
  description = "Name of the pods secondary IP range"
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "Name of the services secondary IP range"
  value       = var.services_range_name
}

output "node_tag" {
  description = "Network tag applied to GKE nodes — must match firewall rule target_tags"
  value       = local.node_tag
}

output "ingress_static_ip" {
  description = "Reserved external IP for the ingress-nginx LoadBalancer"
  value       = google_compute_address.ingress_ip.address
}
