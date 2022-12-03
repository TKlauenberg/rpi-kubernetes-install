# Basic networking

# csr approver
resource "helm_release" "kubelet-csr-approver" {
  name       = "kubelet-csr-approver"
  repository = "https://postfinance.github.io/kubelet-csr-approver"
  chart      = "kubelet-csr-approver"

  namespace = "kube-system"

  set {
    name  = "providerRegex"
    value = "^p."
  }
  set {
    name  = "providerIpPrefixes"
    value = "192.168.178.0/22"
  }
}

module "networking_flannel" {
  source = "./modules/networking-flannel"
}

resource "kubernetes_namespace" "metallb_system" {
  metadata {
    name = "metallb-system"
    labels = {
      app                                  = "metallb"
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

module "networking_metallb" {
  depends_on = [
    kubernetes_namespace.metallb_system,
    module.networking_flannel
  ]
  source = "./modules/networking-metallb"
}

resource "kubectl_manifest" "metallb_addresspool" {
  depends_on = [
    module.networking_metallb
  ]
  yaml_body = yamlencode({
    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "IPAddressPool"
    "metadata" = {
      "name"      = "default"
      "namespace" = "metallb-system"
    }
    "spec" = {
      "addresses"  = ["${var.network_subnet}.210-${var.network_subnet}.250"]
      "autoAssign" = true
    }
  })
}

resource "kubectl_manifest" "mettallb_l2advertisement" {
  depends_on = [
    kubectl_manifest.metallb_addresspool
  ]
  yaml_body = yamlencode({
    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "L2Advertisement"
    "metadata" = {
      "name"      = "default"
      "namespace" = "metallb-system"
    }
    "spec" = {
      "ipAddressPools" = ["default"]
    }
  })
}
