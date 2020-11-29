terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.18"
    }
    ignition = {
      source  = "terraform-providers/ignition"
      version = "~> 1.2.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 1.13.3"
    }
  }
  required_version = ">= 0.13"
}
