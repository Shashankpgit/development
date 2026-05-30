# infra/modules/apis/variables.tf

variable "project_id" {
  description = "GCP project ID in which to enable APIs"
  type        = string
}

# region is passed down from the root terragrunt.hcl as a shared input.
# The apis module does not use it, but declaring it here prevents OpenTofu
# from raising an 'undeclared variable' error when the root passes it in.
variable "region" {
  description = "GCP region (passed from root; not used by this module)"
  type        = string
  default     = ""
}
