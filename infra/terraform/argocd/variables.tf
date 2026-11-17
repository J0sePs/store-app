variable "region" {
  description = "Región de AWS donde está el clúster (la misma de la etapa principal)"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nombre del clúster EKS creado por la etapa principal (infra/terraform)"
  type        = string
  default     = "store-eks"
}

variable "argocd_namespace" {
  description = "Namespace donde se instala Argo CD"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Versión del chart oficial argo-cd (repositorio argoproj.github.io/argo-helm)"
  type        = string
  default     = "10.17.2"
}
