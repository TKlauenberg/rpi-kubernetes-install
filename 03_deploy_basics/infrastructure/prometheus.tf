
# resource "helm_release" "prometheus" {
#   depends_on = [
#     module.networking_flannel, module.networking_metallb
#   ]
#   name       = "prometheus"
#   namespace  = "default"
#   chart      = "kube-prometheus-stack"
#   repository = "https://prometheus-community.github.io/helm-charts"
#   wait       = false
#   set {
#     name  = "grafana.adminPassword"
#     value = "admin"
#   }
#   set {
#     name  = "grafana.plugins"
#     value = "devopsprodigy-kubegraf-app"
#   }
#   # set {
#   #   name  = "prometheus-node-exporter.image.tag"
#   #   value = "v1.1.2"
#   # }
#   # set {
#   #   name = "prometheus.prometheusSpec.image.tag"
#   #   value = "v2.25.1"
#   # }
#   # set {
#   #   name = "prometheus.alertManagerSpec.image.tag"
#   #   value = "v2.25.1"
#   # }
# }

# resource "kubernetes_namespace" "kubegraf" {
#   depends_on = [helm_release.prometheus]
#   metadata {
#     name = "kubegraf"
#   }
# }

# resource "kubernetes_manifest" "kubegraf-serviceaccount" {
#   depends_on = [kubernetes_namespace.kubegraf]
#   manifest = yamldecode(file("./external/kubegraf/kubernetes/serviceaccount.yaml"))
# }

# resource "kubernetes_manifest" "kubegraf-clusterrole" {
#   depends_on = [kubernetes_namespace.kubegraf]
#   manifest = yamldecode(file("./external/kubegraf/kubernetes/clusterrole.yaml"))
# }
# resource "kubernetes_manifest" "kubegraf-clusterrolebinding" {
#   depends_on = [kubernetes_namespace.kubegraf]
#   manifest = yamldecode(file("./external/kubegraf/kubernetes/clusterrolebinding.yaml"))
# }
# resource "kubernetes_manifest" "kubegraf-secret" {
#   depends_on = [kubernetes_namespace.kubegraf]
#   manifest = yamldecode(file("./external/kubegraf/kubernetes/secret.yaml"))
# }

# ## SEE following for the dashboard configuration
# ### https://grafana.com/grafana/plugins/devopsprodigy-kubegraf-app/


# # resource "null_resource" "prometheus_patch" {
# #   depends_on = [helm_release.prometheus]
# #   provisioner "local-exec" {
# #     command = <<EOF
# # kubectl patch ds prometheus-prometheus-node-exporter --type json -p '[{"op": "remove", "path" : "/spec/template/spec/containers/0/volumeMounts/2/mountPropagation"}]' || true
# #     EOF
# #   }
# # }


# resource "kubernetes_ingress" "traefik_grafana_routing" {
#   depends_on = [helm_release.prometheus]
#   metadata {
#     name = "traefik-k8s-grafana"
#     annotations = {
#       "kubernetes.io/ingress.class" : "traefik"
#     }
#     namespace = "default"
#   }

#   spec {
#     rule {
#       host = "grafana.local"
#       http {
#         path {
#           path = "/"
#           backend {
#             service_name = "prometheus-grafana"
#             service_port = 80
#           }
#         }
#       }
#     }
#   }
# }