terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.73.0" # Specific version for AWS provider
    }

    local = {
      source  = "hashicorp/local"
      version = "2.5.2" # Specific version for Local provider
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6" # Specific version for TLS provider
    }
  }

  required_version = ">= 1.9.5" # Minimum Terraform version required
}
