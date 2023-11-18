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
    helm_release.flannel_networking,
    helm_release.metallb_networking,
    kubernetes_namespace.nginx-ingress-namespace
  ]
  name       = "ingress-nginx"
  namespace  = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.8.3"

  values = [yamlencode(
    {
      resources = {
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "512Mi"
        }
      }
      installCRDs = true
    }
  )]
}
