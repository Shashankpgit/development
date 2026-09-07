variable "name_prefix" {
  description = "Prefix for every resource name, e.g. \"shop-dev\"."
  type        = string
}

variable "aws_region" {
  description = "AWS region. Subnet AZs are derived from it as <region><az_suffix>."
  type        = string
}

variable "vpc_cidr" {
  description = <<-EOT
    CIDR for the VPC. /16 gives 65k addresses -- far more than this app needs,
    but a VPC CIDR cannot be resized later, so err large. It costs nothing.
  EOT
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_suffixes" {
  description = <<-EOT
    Availability zone letters to place subnets in, e.g. ["a", "b"].

    TWO IS THE MINIMUM. EKS refuses to create a cluster whose subnets are all
    in one AZ -- the control plane is spread across AZs and needs somewhere to
    put each replica. This is a hard API error, not a warning.
  EOT
  type        = list(string)
  default     = ["a", "b"]

  validation {
    condition     = length(var.az_suffixes) >= 2
    error_message = "EKS requires subnets in at least 2 availability zones."
  }
}

variable "tags" {
  description = "Tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
