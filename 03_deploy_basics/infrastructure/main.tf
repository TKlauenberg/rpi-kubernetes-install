provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kubernetes-admin@raspi"
}

provider "helm" {
  debug = true
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "kubernetes-admin@raspi"
  }
}

provider "kubectl" {
  config_path    = "~/.kube/config"
  config_context = "kubernetes-admin@raspi"
}

variable "network_subnet" {
  type = string
  description = "The Subnet for Kubernetes"
}

variable "nfs_storage" {
  description = "path of nfs storage"
}
variable "images" {
  description = "images used in configuration"
}