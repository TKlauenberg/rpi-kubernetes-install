terraform {
  required_version = ">= 1.1.8"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11.0"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}
