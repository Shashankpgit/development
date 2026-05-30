# infra/modules/gke/outputs.tf

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "External IP of the GKE control plane API server"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true   # endpoint is not a secret but keep it out of plain logs
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster (used by kubectl)"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "node_sa_email" {
  description = "Email of the GKE node service account"
  value       = google_service_account.node_sa.email
}

output "get_credentials_command" {
  description = "The exact gcloud command to configure kubectl for this cluster"
  value = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
}
