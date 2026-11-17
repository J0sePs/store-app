output "argocd_namespace" {
  description = "Namespace donde quedó instalado Argo CD"
  value       = helm_release.argocd.namespace
}

output "argocd_port_forward_command" {
  description = "Comando para abrir la interfaz de Argo CD en https://localhost:8080"
  value       = "kubectl port-forward svc/argocd-server -n ${helm_release.argocd.namespace} 8080:443"
}
