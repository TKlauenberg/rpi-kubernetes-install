# TODO randomize passwords
locals {
  keycloak_db_resource_name = "keycloakdb"
  keycloak_db_user          = "keycloak"
  keycloak_db_password      = "keycloak"
  keycloak_db_name          = "keycloak"
  keycloak_host_name        = "auth.${var.domain_name}"
  keycloak_password         = "keycloak"
  keycloak_namespace        = var.auth_namespace
}

resource "kubernetes_namespace" "auth" {
  metadata {
    name = local.keycloak_namespace
  }
}

resource "kubernetes_secret" "keycloak_db_auth_secret" {
  depends_on = [kubernetes_namespace.auth]
  type       = "kubernetes.io/basic-auth"
  metadata {
    name      = "keycloak-db-auth-secret"
    namespace = local.keycloak_namespace
  }
  data = {
    username = local.keycloak_db_user
    password = local.keycloak_db_password
  }
}

resource "kubectl_manifest" "keycloak_db" {
  depends_on = [
    kubernetes_namespace.auth,
    helm_release.cnpg,
    kubernetes_secret.keycloak_db_auth_secret,
  ]
  yaml_body = yamlencode({
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = local.keycloak_db_resource_name
      namespace = local.keycloak_namespace
    }
    spec = {
      instances : 2

      bootstrap = {
        initdb = {
          database = local.keycloak_db_name
          owner    = local.keycloak_db_user
          secret = {
            name = kubernetes_secret.keycloak_db_auth_secret.metadata[0].name
          }
        }
      }

      storage = {
        storageClass = "nfs-csi-client"
        size : "200Mi"
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "1500m"
          memory = "1Gi"
        }
      }
    }
  })
}

resource "kubernetes_secret" "keycloak_auth_secret" {
  depends_on = [kubernetes_namespace.auth]
  type       = "Opaque"
  metadata {
    name      = "keycloak-auth-secret"
    namespace = local.keycloak_namespace
  }
  data = {
    password = local.keycloak_password
  }
}


resource "helm_release" "keycloak" {
  depends_on = [
    kubernetes_namespace.auth,
    helm_release.certmanager,
    kubectl_manifest.keycloak_db,
    kubernetes_secret.keycloak_auth_secret,
  ]
  name       = "keycloak"
  repository = "https://tklauenberg.github.io/helm"
  chart      = "keycloak"
  namespace  = local.keycloak_namespace
  version    = "0.1.9"

  values = [yamlencode({
    image = {
      repository = "ghcr.io/tklauenberg/keycloak"
      tag        = "22.0"
    }
    ingress = {
      enabled   = true
      className = "nginx"
      hosts = [{
        host = local.keycloak_host_name
        paths = [{
          path     = "/"
          pathType = "Prefix"
        }]
      }]
      tls = [{
        secretName = "keycloak-cert"
        hosts      = [local.keycloak_host_name]
      }]
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-production"
      }
    }
    keycloak = {
      loglevel = "ALL"
      hostname = local.keycloak_host_name

      adminUser = "admin"
      adminPasswordSecret = {
        name = kubernetes_secret.keycloak_auth_secret.metadata[0].name
        key  = "password"
      }

      database = {
        passwordSecret = {
          name = kubernetes_secret.keycloak_db_auth_secret.metadata[0].name
          key  = "password"
        }
        username     = local.keycloak_db_user
        databaseName = local.keycloak_db_name
        schema       = local.keycloak_db_name
        host         = "${local.keycloak_db_resource_name}-rw"
      }
    }
    resources = {
      requests = {
        cpu    = "500m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "1"
        memory = "512Mi"
      }
    }
  })]
  timeout = 150
}

