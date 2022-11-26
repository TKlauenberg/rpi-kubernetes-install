# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

data "kubectl_file_documents" "flannel_base_files" {
  content = file("${path.module}/../../external/flannel/Documentation/kube-flannel.yml")
}

resource "kubectl_manifest" "flannel_networking" {
  for_each  = data.kubectl_file_documents.flannel_base_files.manifests
  yaml_body = each.value
}

resource "kubernetes_config_map_v1_data" "flannel_networking_patch" {
  depends_on = [
    kubectl_manifest.flannel_networking
  ]
  metadata {
    name      = "kube-flannel-cfg"
    namespace = "kube-flannel"
  }
  force = true
  data = {
    "net-conf.json" = "{\r\n\t\"Network\": \"10.244.0.0/16\",\r\n\t\"Backend\": { \r\n\t\t\"Type\": \"host-gw\"\n\t}\n}"
  }
}
