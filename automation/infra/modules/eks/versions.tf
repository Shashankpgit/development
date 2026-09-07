terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Used once, to read the OIDC issuer's certificate so its thumbprint can be
    # computed rather than hardcoded. AWS has rotated that thumbprint before.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
