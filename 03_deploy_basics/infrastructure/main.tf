provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "${var.context_name}"
}

provider "helm" {
  debug = true
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "${var.context_name}"
  }
}

provider "kubectl" {
  config_path    = "~/.kube/config"
  config_context = "${var.context_name}"
}

variable "network_subnet" {
  type = string
  description = "The Subnet for Kubernetes"
}

variable "context_name" {
  type = string
  description = "The context name for Kubernetes"
}

variable "nfs_storage" {
  description = "path of nfs storage"
}
variable "images" {
  description = "images used in configuration"
}