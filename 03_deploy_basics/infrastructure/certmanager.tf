resource "helm_release" "certmanager" {
  depends_on = [
    helm_release.metallb_networking
  ]
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  version          = "v1.17.1"
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

resource "kubectl_manifest" "issuer-staging" {
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
        "email"  = var.letsencrypt_email
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

resource "kubectl_manifest" "issuer-production" {
  depends_on = [
    helm_release.certmanager
  ]
  yaml_body = yamlencode({
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name"    = "letsencrypt-production"
      namespace = helm_release.certmanager.namespace
    }
    "spec" = {
      "acme" = {
        "email"  = var.letsencrypt_email
        # production server
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "privateKeySecretRef" = {
          "name" = "letsencrypt-account"
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
