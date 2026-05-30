# infra/modules/gke/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster (regional cluster spans all zones in the region)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "vault-cluster"
}

variable "node_pool_name" {
  description = "Name of the GKE node pool"
  type        = string
  default     = "vault-nodes"
}

variable "node_sa_name" {
  description = "account_id of the GKE node service account (short name, not full email)"
  type        = string
  default     = "vault-gke-node-sa"
}

variable "machine_type" {
  description = "GCE machine type for worker nodes (e.g. e2-standard-2, n2-standard-4)"
  type        = string
  default     = "e2-standard-2"
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "disk_size_gb" {
  description = "Size of each node's boot disk in GB"
  type        = number
  default     = 50
}

variable "k8s_version" {
  description = "Kubernetes minor version to pin (e.g. '1.30'). GKE manages patch upgrades."
  type        = string
  default     = "1.30"
}

variable "node_tag" {
  description = "Network tag applied to nodes. Must match target_tags in the network module's firewall rules."
  type        = string
  default     = "gke-node"
}

# ── Passed from the network module via dependency outputs ──────────────────────

variable "network_name" {
  description = "Name of the VPC network (from network module output vpc_name)"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet (from network module output subnet_name)"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the pods secondary IP range (from network module output pods_range_name)"
  type        = string
}

variable "services_range_name" {
  description = "Name of the services secondary IP range (from network module output services_range_name)"
  type        = string
}
