# install driver for storage class
resource "helm_release" "nfs-csi-driver" {
  depends_on = [
    helm_release.flannel_networking,
    helm_release.metallb_networking,
    helm_release.ingress-nginx
  ]
  name       = "nfs-csi-driver"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart      = "csi-driver-nfs"
  version    = "4.10.0"
  namespace  = "kube-system"

  values = [yamlencode({
    image = {
      nfs = {
        pullpolicy = "Always"
      }
    }
  })]
}

resource "kubernetes_manifest" "storage_class" {
  depends_on = [
    helm_release.nfs-csi-driver
  ]
  manifest = {
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "nfs-csi-client"
      annotations = {
        "storageclass.kubernetes.io/is-default-class" = "true"
      }
    }
    provisioner = "nfs.csi.k8s.io"
    parameters = {
      "server" = var.nfs_storage.server
      "share"  = var.nfs_storage.path
      "subDir" = "csi/$${pvc.metadata.namespace}/$${pvc.metadata.name}/$${pv.metadata.name}"
    }
    volumeBindingMode    = "Immediate"
    reclaimPolicy        = "Retain"
    allowVolumeExpansion = true
  }

}
