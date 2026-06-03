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
  description = "GCP region where the subnet is created"
  type        = string
}

variable "subnet_cidr" {
  description = "Primary CIDR for the subnet. Node IPs come from here."
  type        = string
  default     = "10.0.0.0/24"
}

variable "pods_range_name" {
  description = "Name of the secondary IP range for GKE pod IPs"
  type        = string
  default     = "pods"
}

variable "pods_cidr" {
  description = "CIDR for the pods secondary range"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_range_name" {
  description = "Name of the secondary IP range for GKE service ClusterIPs"
  type        = string
  default     = "services"
}

variable "services_cidr" {
  description = "CIDR for the services secondary range"
  type        = string
  default     = "10.2.0.0/20"
}
