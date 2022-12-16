# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

data "kubectl_file_documents" "flannel_base_files" { content = file("${path.module}/../../external/flannel/Documentation/kube-flannel.yml") }

locals {
  filtercfg = {
    for key, val in data.kubectl_file_documents.flannel_base_files.manifests :
    key => val
    if yamldecode(val).metadata.name != "kube-flannel-cfg"
  }
  filterds = {
    for key, val in local.filtercfg :
    key => val
    if yamldecode(val).metadata.name != "kube-flannel-ds"
  }
  dsvalue = [
    for key, val in data.kubectl_file_documents.flannel_base_files.manifests :
    val
    if yamldecode(val).metadata.name == "kube-flannel-ds"
  ]
  flannel_base_config = [
    for key, val in data.kubectl_file_documents.flannel_base_files.manifests :
    val
    if yamldecode(val).metadata.name == "kube-flannel-cfg"
  ]
}

resource "kubectl_manifest" "flannel_networking" {
  for_each  = local.filterds
  yaml_body = each.value
}

resource "kubernetes_config_map_v1" "flannel_networking" {
  depends_on = [
    kubectl_manifest.flannel_networking
  ]
  metadata {
    name      = "kube-flannel-cfg"
    namespace = "kube-flannel"
  }
  data = {
    "cni-conf.json" = yamldecode(local.flannel_base_config[0]).data["cni-conf.json"]
    "net-conf.json" = "{\r\n\t\"Network\": \"10.244.0.0/16\",\r\n\t\"Backend\": { \r\n\t\t\"Type\": \"host-gw\"\n\t}\n}"
  }
}

resource "kubectl_manifest" "flannel_networking_ds" {
  depends_on = [
    kubernetes_config_map_v1.flannel_networking
  ]
  yaml_body = local.dsvalue[0]
}
