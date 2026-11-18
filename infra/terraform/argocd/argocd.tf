# Instala Argo CD con el chart oficial. Esta etapa no contiene manifiestos de la aplicación:
# la aplicación raíz (root-app) se aplica a mano una sola vez desde el repositorio store-gitops.
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.argocd_namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  create_namespace = true
  atomic           = true
  wait             = true
  timeout          = 900

  # Valores en values.yaml: Argo CD reducido a 4 pods para nodos t3.small (sin dex, notifications ni ApplicationSet)
  values = [file("${path.module}/values.yaml")]
}
