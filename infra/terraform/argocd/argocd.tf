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

  values = [
    yamlencode({
      server = {
        # Sin balanceador (ahorra costo): la interfaz se abre con kubectl port-forward
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]
}
