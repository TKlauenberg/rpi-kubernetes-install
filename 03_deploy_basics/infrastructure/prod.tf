resource "kubernetes_namespace" "prod" {
  depends_on = [ helm_release.k8s_dashboard ]
  metadata {
    name = var.prod_namespace
  }
}
