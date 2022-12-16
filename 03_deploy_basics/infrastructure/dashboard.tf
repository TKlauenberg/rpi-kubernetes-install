## Install metrics server
resource "helm_release" "metrics_server" {
  depends_on = [
    kubectl_manifest.mettallb_l2advertisement
  ]
  name       = "k8s-metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
}

## Install dashboard
resource "helm_release" "k8s_dashboard" {
  depends_on = [
    helm_release.metrics_server
  ]
  name       = "k8s-dashboard"
  namespace  = "default"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"

  set {
    name  = "protocolHttp"
    value = "true"
  }
  set {
    name  = "rbac.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "service.externalPort"
    value = "1337"
  }
  set {
    name  = "networkPolicy.enabled"
    value = "true"
  }
  set {
    name  = "podLabels.app"
    value = "k8s-dashboard"
  }
  set {
    name  = "metrics-server.enabled"
    value = "false"
  }
  set {
    name  = "metricsScraper.enabled"
    value = "true"
  }
  set {
    name  = "metricsScraper.image.repository"
    value = "kubernetesui/metrics-scraper-arm"
  }
  set {
    name  = "metricsScraper.image.tag"
    value = "latest"
  }
}

resource "kubernetes_cluster_role_binding" "k8s_dashboard_role" {
  depends_on = [
    helm_release.k8s_dashboard
  ]
  metadata {
    name = "kubernetes-dashboard"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "k8s-dashboard-kubernetes-dashboard"
    namespace = "default"
  }
}
