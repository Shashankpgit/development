variable "project_id" {
  description = "GCP project ID"
  type        = string
}

# region is passed from the root terragrunt.hcl as a shared input.
# This module does not use it — enabling APIs is project-wide, not regional.
# Declaring it here prevents OpenTofu from raising an 'unsupported argument' error.
variable "region" {
  description = "GCP region (passed from root, not used by this module)"
  type        = string
  default     = ""
}

# env_name and app_name are passed from root as shared inputs.
# Not used here but declared to avoid 'unsupported argument' errors.
variable "env_name" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  default     = ""
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = ""
}
