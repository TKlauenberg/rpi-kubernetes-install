resource "kubernetes_namespace" "nginx-ingress-namespace" {
  metadata {
    name = "ingress-nginx"
    labels = {
      app = "ingress-nginx"
    }
  }
}

resource "helm_release" "ingress-nginx" {
  depends_on = [
    module.networking_flannel, module.networking_metallb, kubernetes_namespace.nginx-ingress-namespace
  ]
  name      = "ingress-nginx"
  namespace = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart     = "ingress-nginx"
}