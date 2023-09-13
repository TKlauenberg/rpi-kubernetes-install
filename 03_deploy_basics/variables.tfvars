# Variables used for barebone kubernetes setup
network_subnet = "192.168.178"

context_name = "kubernetes-context-name"

nfs_storage = {
  server = "nfs-server"
  path = "/path/to/nfs"
}

# Images definition to make it easier to update
images = {
  etcd = "gcr.io/etcd-development/etcd:v3.5.6-arm64"
  # special compatibility with kubernetes version needed!
  # look up compatibility here: https://github.com/kubernetes/kube-state-metrics#compatibility-matrix
  kube_state_metrics = ""
}
