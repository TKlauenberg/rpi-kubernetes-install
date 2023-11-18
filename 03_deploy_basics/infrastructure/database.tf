# data "kubectl_file_documents" "cloudnative_pg" { content = file("${path.module}/static/external/cloudnative-pg/releases/cnpg-1.21.1.yaml") }


# resource "kubectl_manifest" "cloudnative_pg" {
#   for_each  = data.kubectl_file_documents.cloudnative_pg.manifests
#   yaml_body = each.value
# }

resource "helm_release" "cnpg" {
  name = "cnpg"
  repository = "https://cloudnative-pg.github.io/charts"
  chart = "cloudnative-pg"
  namespace = "cnpg-system"
  version = "0.19.1"
  create_namespace = true
}
