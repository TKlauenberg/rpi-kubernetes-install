resource "kubernetes_config_map_v1_data" "metallb_networking_patch" {
  metadata {
    name      = "kube-proxy"
    namespace = "kube-system"
  }
  data = {
    "net-conf.json" = "{\r\n\t\"Network\": \"10.244.0.0/16\",\r\n\t\"Backend\": { \r\n\t\t\"Type\": \"host-gw\"\n\t}\n}"
  }
}


resource "helm_release" "metallb_networking" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"

  cleanup_on_fail = true
  force_update    = true
  namespace       = "metallb-system"
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