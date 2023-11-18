# TODO randomize passwords
locals {
  keycloak_db_resource_name = "keycloakdb"
  keycloak_db_user          = "keycloak"
  keycloak_db_password      = "keycloak"
  keycloak_db_name          = "keycloak"
  keycloak_host_name        = "keycloak.tobias-klauenberg.net"
  keycloak_password         = "keycloak"
}

resource "kubernetes_secret" "keycloak_db_auth_secret" {
  type = "kubernetes.io/basic-auth"
  metadata {
    name      = "keycloak-db-auth-secret"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
  data = {
    username = local.keycloak_db_user
    password = local.keycloak_db_password
  }
}

# resource "kubernetes_secret" "keycloak_db" {
#   depends_on = [
#     kubectl_manifest.kubegres,
#     kubernetes_namespace.prod
#   ]
#   metadata {
#     name      = "keycloak-db"
#     namespace = kubernetes_namespace.prod.metadata[0].name
#   }
#   type = "Opaque"
#   data = {
#     "POSTGRES_REPLICATION_PASSWORD" = local.kubegres_replication_password
#     "POSTGRES_DB"                   = local.kubegres_db
#     "POSTGRES_PASSWORD"             = local.kubegres_password
#     "KEYCLOAK_DB_USER"              = local.keycloak_db_user
#     "KEYCLOAK_DB_PASSWORD"          = local.keycloak_db_password
#     "KEYCLOAK_DB_NAME"              = local.keycloak_db_name
#     "POSTGRES_CONNECTION_STRING" = "postgresql://postgres:${local.kubegres_password}@${local.keycloak_db_resource_name}:5432/${local.kubegres_db}"
#   }
# }

resource "kubectl_manifest" "keycloak_db" {
  depends_on = [
    kubernetes_namespace.prod,
    helm_release.cnpg
    # kubernetes_secret.keycloak_db
  ]
  yaml_body = yamlencode({
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = local.keycloak_db_resource_name
      namespace = kubernetes_namespace.prod.metadata[0].name
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
        size : "200Mi"
      }
    }
    resources = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
  })
}

resource "kubernetes_secret" "keycloak_auth_secret" {
  type = "Opaque"
  metadata {
    name      = "keycloak-auth-secret"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
  data = {
    password = local.keycloak_password
  }
}


resource "helm_release" "keycloak" {
  depends_on = [
    kubectl_manifest.keycloak_db,
    kubernetes_secret.keycloak_auth_secret,
  ]
  name       = "keycloak"
  repository = "https://tklauenberg.github.io/helm"
  chart      = "keycloak"
  namespace  = kubernetes_namespace.prod.metadata[0].name
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
        "cert-manager.io/cluster-issuer" = "letsencrypt-staging"
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
        cpu    = "4"
        memory = "512Mi"
      }
    }
  })]
  timeout = 150
}

