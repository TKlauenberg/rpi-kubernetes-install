resource "helm_release" "nfs_provisioner" {
  depends_on = [
    helm_release.flannel_networking,
    helm_release.metallb_networking,
    helm_release.ingress-nginx
  ]

  name       = "nfs-subdir-provisioner"
  repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart      = "nfs-subdir-external-provisioner"
  version = "4.0.18"

  set {
    name  = "nfs.server"
    value = var.nfs_storage.server
  }

  set {
    name  = "nfs.path"
    value = var.nfs_storage.path
  }

  set {
    name  = "storageClass.defaultClass"
    value = "true"
  }

}
