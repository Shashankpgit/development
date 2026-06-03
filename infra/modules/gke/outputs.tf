output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Endpoint of the GKE control plane API server"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "node_sa_email" {
  description = "Email of the GKE node service account"
  value       = google_service_account.node_sa.email
}

output "get_credentials_command" {
  description = "Run this command to configure kubectl after apply"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
}
