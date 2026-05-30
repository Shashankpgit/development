# infra/modules/network/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region where the subnet, Cloud Router, NAT, and static IP are created"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network (also used as a prefix for router, NAT, IP, firewall rule names)"
  type        = string
  default     = "vault-vpc"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "vault-subnet"
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the subnet. Node IPs are drawn from this range."
  type        = string
  default     = "10.0.0.0/24"
}

variable "pods_range_name" {
  description = "Name of the secondary IP range used for GKE pod IPs"
  type        = string
  default     = "pods"
}

variable "pods_cidr" {
  description = "CIDR for the pods secondary range. /16 gives 65,536 pod IPs."
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_range_name" {
  description = "Name of the secondary IP range used for GKE service (ClusterIP) IPs"
  type        = string
  default     = "services"
}

variable "services_cidr" {
  description = "CIDR for the services secondary range. /20 gives 4,096 service IPs."
  type        = string
  default     = "10.2.0.0/20"
}

variable "node_tag" {
  description = "Network tag applied to GKE nodes. Firewall rules target this tag."
  type        = string
  default     = "gke-node"
}
