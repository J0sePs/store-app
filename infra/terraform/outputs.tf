output "cluster_name" {
  description = "Nombre del clúster EKS"
  value       = module.eks.cluster_name
}

output "region" {
  description = "Región de AWS de la infraestructura"
  value       = var.region
}

output "ecr_repository_urls" {
  description = "URL de cada repositorio ECR, por nombre"
  value       = { for name, repo in module.ecr : name => repo.repository_url }
}

output "github_actions_role_arn" {
  description = "ARN del rol IAM que asume GitHub Actions (variable AWS_ROLE_ARN en GitHub)"
  value       = module.github_actions_role.arn
}

output "update_kubeconfig_command" {
  description = "Comando para configurar kubectl contra el clúster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}
