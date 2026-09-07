# ============================================================================
# Root config, included by every component in this environment.
#
# Its one job: generate the backend and provider blocks, so no component has
# to repeat them and no two components can disagree about where state lives.
# ============================================================================

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {
    # Exported by tf.sh, which create_tf_backend.sh writes for you.
    bucket = "${get_env("TF_STATE_BUCKET", "")}"

    # path_relative_to_include() -> "network/terraform.tfstate",
    # "eks/terraform.tfstate". Each component gets its OWN state file, which is
    # what makes it possible to destroy the cluster without touching the VPC.
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "${get_env("AWS_REGION", "ap-south-1")}"

    encrypt = true

    # State locking via an S3 conditional-write lock file (OpenTofu >= 1.10).
    # The old way required a whole DynamoDB table just for this. Locking is
    # what stops two concurrent applies from interleaving writes and
    # corrupting state.
    use_lockfile = true
  }
}
EOF
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${get_env("AWS_REGION", "ap-south-1")}"

  # Applied to every taggable resource, on top of whatever each module sets.
  # This is how you can later answer "what is this cluster costing me?" in
  # Cost Explorer -- untagged resources are effectively invisible there.
  default_tags {
    tags = {
      ManagedBy = "opentofu"
      Repo      = "learn/dev/development"
    }
  }
}
EOF
}
