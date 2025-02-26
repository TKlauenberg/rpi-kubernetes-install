
locals {
  # TODO currently manual task
  argocd_keycloak_client_secret = "Ni6ziwYvtjV69qI3miDETesAMzv1Cbz7"
  argocd_host_name              = "argocd.${var.domain_name}"
}



resource "helm_release" "argocd" {
  depends_on       = [helm_release.keycloak]
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.8.5"

  values = [yamlencode({
    dex = {
      enabled = false
    }
    configs = {
      cm = {
        # argocd url
        url             = "https://${local.argocd_host_name}"
        "admin.enabled" = false
        "oidc.config" = yamlencode({
          name            = "keycloak"
          issuer          = "https://${local.keycloak_host_name}/realms/master"
          clientID        = "argocd"
          clientSecret    = "$oidc.keycloak.clientSecret"
          requestedScopes = ["openid", "profile", "email"]
        })
      }
      rbac = {
        "policy.csv" = "g, ArgoCDAdmin, role:admin\ng, ArgoCDReader, role:readonly"
      }
      secret = {
        extra = {
          "oidc.keycloak.clientSecret" = local.argocd_keycloak_client_secret
        }
      }
    }
    server = {
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        hostname         = local.argocd_host_name
        https            = true
        tls              = true
        annotations = {
          "cert-manager.io/cluster-issuer"               = "letsencrypt-production",
          "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
          "nginx.ingress.kubernetes.io/ssl-passthrough"  = "true",
        }
      }
    }
    global = {
      logging = {
        format = "json"
      }
    }
    resources = {
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  })]
}

resource "helm_release" "sealed-secrets" {
  depends_on = [helm_release.argocd]
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  name       = "sealed-secrets"
  version    = "2.17.1"
  namespace  = "kube-system"
  set {
    name  = "fullnameOverride"
    value = "sealed-secrets-controller"
  }
}
