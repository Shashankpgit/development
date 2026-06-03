variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "env_name" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC (from network module output)"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet (from network module output)"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the pods secondary IP range (from network module output)"
  type        = string
}

variable "services_range_name" {
  description = "Name of the services secondary IP range (from network module output)"
  type        = string
}

variable "machine_type" {
  description = "GCE machine type for worker nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "node_tag" {
  description = "Network tag applied to nodes — must match firewall rule target_tags in network module"
  type        = string
}

variable "disk_type" {
  description = "Boot disk type for nodes. Use pd-standard to stay within free tier SSD quota."
  type        = string
  default     = "pd-standard"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB for each node"
  type        = number
  default     = 30
}
