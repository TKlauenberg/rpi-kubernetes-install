# Basic networking

resource "helm_release" "flannel_networking" {
  # depends_on = [
  #   kubernetes_namespace.kube_flannel
  # ]
  name       = "flannel"
  repository = "https://flannel-io.github.io/flannel/"
  chart      = "flannel"

  cleanup_on_fail  = true
  force_update     = true
  namespace        = "kube-system"
  version          = "v0.26.4"
  timeout          = 60

  set {
    name  = "podCidr"
    value = "10.244.0.0/16"
  }
  set {
    name  = "flannel.backend"
    value = "host-gw"
  }
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

resource "helm_release" "metallb_networking" {
  depends_on = [kubernetes_namespace.metallb_system, helm_release.flannel_networking]
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"

  cleanup_on_fail = true
  force_update    = true
  namespace       = "metallb-system"
  version         = "0.14.9"
}

resource "random_string" "metallb_secret_string" {
  depends_on = [
    helm_release.metallb_networking
  ]
  length  = 128
  special = false
}

resource "kubernetes_secret" "metallb_secret" {
  depends_on = [
    helm_release.metallb_networking
  ]
  type = "generic"
  metadata {
    name      = "memberlist"
    namespace = "metallb-system"
  }
  data = {
    secretkey = base64encode(random_string.metallb_secret_string.result)
  }
}

resource "kubectl_manifest" "metallb_addresspool" {
  depends_on = [
    helm_release.metallb_networking
  ]
  yaml_body = yamlencode({
    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "IPAddressPool"
    "metadata" = {
      "name"      = "default"
      "namespace" = "metallb-system"
    }
    "spec" = {
      "addresses"  = ["${var.network_subnet}.230-${var.network_subnet}.250"]
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

# csr approver
resource "helm_release" "kubelet-csr-approver" {
  depends_on = [helm_release.metallb_networking]
  name       = "kubelet-csr-approver"
  repository = "https://postfinance.github.io/kubelet-csr-approver"
  chart      = "kubelet-csr-approver"
  namespace  = "kube-system"
  version    = "1.2.6"

  set {
    name  = "providerRegex"
    value = "^p."
  }
  set {
    name  = "providerIpPrefixes"
    value = "192.168.178.0/22"
  }

  values = [yamlencode(
    {
      resources = {
        requests = {
          cpu    = "20m"
          memory = "32Mi"
        }
        limits = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }
      installCRDs = true
    }
  )]
}
