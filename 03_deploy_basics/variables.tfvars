# Variables used for barebone kubernetes setup
network_subnet = "192.168.178"

net_hosts = {
  traefik = "234"
}

nfs_storage = {
  general = "/media/nfs"
}

# Images definition to make it easier to update
images = {
  etcd = "gcr.io/etcd-development/etcd:v3.5.5-arm64"
}
