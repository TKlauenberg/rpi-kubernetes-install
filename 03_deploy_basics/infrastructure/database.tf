
resource "helm_release" "cnpg" {
  name = "cnpg"
  repository = "https://cloudnative-pg.github.io/charts"
  chart = "cloudnative-pg"
  namespace = "cnpg-system"
  version = "0.19.1"
  create_namespace = true
}
