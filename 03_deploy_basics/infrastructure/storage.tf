resource "helm_release" "nfs_provisioner" {
  depends_on = [
    module.networking_flannel,
    module.networking_metallb,
    helm_release.ingress-nginx
  ]

  name       = "nfs-subdir-provisioner"
  repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart      = "nfs-subdir-external-provisioner"

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
