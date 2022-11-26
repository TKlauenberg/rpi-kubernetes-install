# Basic networking

module "networking_flannel" {
  source = "./modules/networking-flannel"
}

resource "kubernetes_namespace" "metallb_system" {
  metadata {
    name = "metallb-system"
    labels = {
      app = "metallb"
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit" = "privileged"
      "pod-security.kubernetes.io/warn" = "privileged"
    }
  }
}

module "networking_metallb" {
  depends_on = [kubernetes_namespace.metallb_system]
  source     = "./modules/networking-metallb"
}

# resource "kubernetes_config_map" "metallb_cfg_map" {
#   depends_on = [
#     module.networking_metallb
#   ]
#   metadata {
#     name      = "config"
#     namespace = "metallb-system"
#   }

#   data = {
#     config = <<CFGMAP
#   address-pools:
#   - name: default
#     protocol: layer2
#     addresses:
#     - ${var.network_subnet}.200-${var.network_subnet}.250
#     CFGMAP
#   }
# }

resource "kubernetes_manifest" "metallb_addresspool" {
  depends_on = [
    module.networking_metallb
  ]
  manifest = {
    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "IPAddressPool"
    "metadata" = {
      "name"      = "default"
      "namespace" = "metallb-system"
    }
    "spec" = {
      "addresses" = ["${var.network_subnet}.210-${var.network_subnet}.250"]
      "autoAssign" = "true"
    }
  }
}

resource "kubernetes_manifest" "mettallb_l2advertisement" {
  depends_on = [
    kubernetes_manifest.metallb_addresspool
  ]
  manifest = {
    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "L2Advertisement"
    "metadata" = {
      "name"      = "default"
      "namespace" = "metallb-system"
    }
    "spec" = {
      "ipAddressPools" = ["default"]
    }
  }
}
