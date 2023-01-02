resource "kubernetes_namespace" "monitoring-namespace" {
  metadata {
    name = "monitoring"
    labels = {
      app = "monitoring"
    }
  }
}

locals {
  influx_name          = "influx-monitor"
  namespace_name       = kubernetes_namespace.monitoring-namespace.metadata[0].name
  influx_template_name = "influx-template"
  influx_bucket        = "metrics"
  influx_organization  = "monitor"
}

resource "kubernetes_secret" "influxdb_template" {
  depends_on = [
    kubernetes_namespace.monitoring-namespace
  ]
  metadata {
    name      = local.influx_template_name
    namespace = local.namespace_name
  }
  data = {
    "k8s.yml" = file("${path.root}/static/external/community-templates/k8s/k8s.yml"),
    "log.yml" = file("${path.root}/static/log.yml"),
  }
}

resource "helm_release" "influxdb2" {
  depends_on = [
    module.networking_flannel,
    module.networking_metallb,
    helm_release.ingress-nginx,
    kubernetes_namespace.monitoring-namespace,
    helm_release.nfs_provisioner,
  ]
  name       = "influxdb"
  repository = "https://helm.influxdata.com"
  chart      = "influxdb2"
  namespace  = local.namespace_name

  set {
    name  = "image.tag"
    value = "2.6.1-alpine"
  }

  values = [yamlencode({
    nameOverride = local.influx_name
    resources = {
      requests = {
        cpu    = "200m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "1"
        memory = "2Gi"
      }
    }
    adminUser = {
      organization = local.influx_organization
      bucket       = local.influx_bucket
      user         = "admin"
    }
    volumes = [{
      name = "influx-template"
      secret = {
        secretName = kubernetes_secret.influxdb_template.metadata[0].name
      }
    }]
    mountPoints = [{
      name      = "influx-template"
      mountPath = "/influxdb2-templates"
      readOnly  = true
    }]
    initScripts = {
      enabled = true
      scripts = {
        "init.sh" = <<-EOT
        #!/bin/bash
        influx apply --force yes -f /influxdb2-templates/k8s.yml
        influx bucket create -n fluentbit
        influx apply --force yes -f /influxdb2-templates/log.yml
        EOT
      }
    }
    ingress = {
      enabled   = true
      className = "nginx"
      hostname  = "influxdb.cluster.local"
      path      = "/"
    }
  })]
}

data "kubernetes_service" "influxdb" {
  depends_on = [
    helm_release.influxdb2
  ]
  metadata {
    name      = "influxdb-${local.influx_name}"
    namespace = local.namespace_name
  }
}

data "kubernetes_secret" "influxdb_secrets" {
  depends_on = [
    helm_release.influxdb2
  ]
  metadata {
    name      = "influxdb-${local.influx_name}-auth"
    namespace = local.namespace_name
  }

}


locals {
  influxdb_svc_name = data.kubernetes_service.influxdb.metadata[0].name
  influxdb_port     = data.kubernetes_service.influxdb.spec[0].port[index(data.kubernetes_service.influxdb.spec[0].port.*.name, "http")].port
  influxdb_token    = data.kubernetes_secret.influxdb_secrets.data.admin-token
}

resource "helm_release" "kube-state-metrics" {
  depends_on = [
    helm_release.influxdb2
  ]
  name       = "kube-state-metrics"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-state-metrics"
  namespace  = "kube-system"


  values = [yamlencode({
    config = {
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
    }
  })]
}


resource "helm_release" "telegraf-ds" {
  depends_on = [
    helm_release.influxdb2
  ]
  name       = "telegraf-ds"
  repository = "https://helm.influxdata.com"
  chart      = "telegraf-ds"
  namespace  = local.namespace_name


  values = [
    yamlencode({
      config = {
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
      }
    }),
    yamlencode({
      config = {
        outputs = [
          {
            influxdb_v2 = {
              urls         = ["http://${local.influxdb_svc_name}:${local.influxdb_port}"]
              token        = local.influxdb_token
              bucket       = local.influx_bucket
              organization = local.influx_organization
            }
          }
        ]
      }
    }),
  ]

  # alpine image is not compatible with arm64/v8
  set {
    name  = "image.tag"
    value = "1.24"
  }

  # default socket is doocker socket in telegraf.
  # so we set it to crio socket
  set {
    name  = "config.docker_endpoint"
    value = ""
  }
}

locals {
  telegraf_svc_account = "telegraf-svc-account"
}

resource "kubernetes_cluster_role" "influx_cluster_viewer" {
  depends_on = [
    kubernetes_namespace.monitoring-namespace,
    helm_release.telegraf-ds,
  ]
  metadata {
    name = "influx:cluster:viewer"
    labels = {
      "rbac.authorization.k8s.io/aggregate-view-telegraf" = true
    }
  }
  rule {
    api_groups = [""]
    resources  = ["persistentvolumes", "nodes"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role" "influx_telegraf" {
  depends_on = [
    kubernetes_cluster_role.influx_cluster_viewer,
  ]
  metadata {
    name = "influx:telegraf:aggregate"
  }
  aggregation_rule {
    cluster_role_selectors {
      match_labels = {
        "rbac.authorization.k8s.io/aggregate-view-telegraf" = true

      }
    }
    cluster_role_selectors {
      match_labels = {
        "rbac.authorization.k8s.io/aggregate-to-view" = true
      }
    }
  }
}


resource "kubernetes_service_account" "influx_telegraf" {
  depends_on = [
    kubernetes_namespace.monitoring-namespace,
    helm_release.telegraf-ds,
  ]
  metadata {
    name      = local.telegraf_svc_account
    namespace = local.namespace_name
  }
}

resource "kubernetes_secret_v1" "influx_telegraf_svc_account" {
  depends_on = [
    kubernetes_service_account.influx_telegraf
  ]
  metadata {
    name      = "${local.telegraf_svc_account}-secret"
    namespace = local.namespace_name
    annotations = {
      "kubernetes.io/service-account.name" = local.telegraf_svc_account
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role_binding" "influx_telegraf_binding" {
  depends_on = [
    kubernetes_service_account.influx_telegraf,
    kubernetes_cluster_role.influx_telegraf
  ]
  metadata {
    name = "influx:telegraf:${local.telegraf_svc_account}"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "influx:telegraf:aggregate"
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.telegraf_svc_account
    namespace = local.namespace_name
  }
}

resource "helm_release" "telegraf" {
  depends_on = [
    helm_release.influxdb2,
    kubernetes_cluster_role_binding.influx_telegraf_binding,
  ]
  name       = "telegraf"
  repository = "https://helm.influxdata.com"
  chart      = "telegraf"
  namespace  = local.namespace_name

  values = [
    yamlencode({
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
    }),
    yamlencode({
      config = {
        outputs = [
          {
            influxdb_v2 = {
              urls         = ["http://${local.influxdb_svc_name}:${local.influxdb_port}"]
              token        = local.influxdb_token
              bucket       = local.influx_bucket
              organization = local.influx_organization
            }
          }
        ]
        inputs = [
          {
            kube_inventory = {
              url                  = "https://kubernetes.default.svc"
              namespace            = ""
              bearer_token         = "/var/run/secrets/kubernetes.io/serviceaccount/token"
              insecure_skip_verify = true
            }
          }
        ]
      }
      rbac = {
        create = false
      }
      serviceAccount = {
        create = false
        name   = local.telegraf_svc_account
      }
      # disable service because it isn's used in this configuration
      service = {
        enabled = false
      }
    }),
  ]

  # alpine image is not compatible with arm64/v8
  set {
    name  = "image.tag"
    value = "1.24"
  }
}

resource "helm_release" "fluentbit" {
  depends_on = [
    helm_release.influxdb2,
    kubernetes_cluster_role_binding.influx_telegraf_binding,
  ]
  name       = "fluentbit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  namespace  = local.namespace_name

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    }),
    yamlencode({
      config = {
        inputs = <<-EOT
          [INPUT]
              Name              tail
              Path              /var/log/containers/*.log
              multiline.parser  cri
              Tag               kube.*
              Mem_Buf_Limit     5MB
              Skip_Long_Lines   On
              DB                /fluent.db
        EOT
        filters = <<-EOT
        [FILTER]
            Name kubernetes
            Match kube.*
            Merge_Log On
            Keep_Log Off
            K8S-Logging.Parser On
            K8S-Logging.Exclude On
        EOT
        outputs = <<-EOT
          [OUTPUT]
              Name          influxdb
              Match         kube.*
              Host          ${local.influxdb_svc_name}
              Port          ${local.influxdb_port}
              Org           ${local.influx_organization}
              Bucket        fluentbit
              HTTP_Token    ${local.influxdb_token}
              Sequence_Tag  _seq
        EOT
        customParsers = ""
      }
    }),
  ]
}
