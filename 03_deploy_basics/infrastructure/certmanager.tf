resource "helm_release" "certmanager" {
  depends_on = [
    helm_release.metallb_networking
  ]
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  version          = "v1.13.2"
  create_namespace = true
  # TODO add monitoring to influxdb!
  values = [yamlencode(
    {
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
      installCRDs = true
    }
  )]

}

resource "kubectl_manifest" "issuer" {
  depends_on = [
    helm_release.certmanager
  ]
  yaml_body = yamlencode({
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name"    = "letsencrypt-staging"
      namespace = helm_release.certmanager.namespace
    }
    "spec" = {
      "acme" = {
        "email"  = "toklaui@live.de"
        "server" = "https://acme-staging-v02.api.letsencrypt.org/directory"
        "privateKeySecretRef" = {
          "name" = "letsencrypt-staging-account"
        }
        "solvers" = [{
          "http01" = {
            "ingress" = {
              "class" = "nginx"
            }
          }
        }]
      }
    }
  })
}
