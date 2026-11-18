# --- General ---

variable "region" {
  description = "Región de AWS donde se crea la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nombre del clúster EKS (también lo usa la etapa de Argo CD para encontrarlo)"
  type        = string
  default     = "store-eks"
}

# --- Red ---

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Cantidad de zonas de disponibilidad que usa la VPC (mínimo 2, que EKS exige)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "EKS necesita al menos 2 zonas de disponibilidad."
  }
}

# --- EKS ---

variable "kubernetes_version" {
  description = "Versión de Kubernetes del clúster (debe estar en soporte estándar de EKS)"
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  description = "Tipos de instancia del grupo de nodos administrado. t3.small porque el plan Gratuito de AWS solo permite instancias elegibles para la capa gratuita (t3.medium falla con 'not eligible for Free Tier'); en una cuenta de pago se puede usar [\"t3.medium\"] desde terraform.tfvars"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_min_size" {
  description = "Cantidad mínima de nodos"
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Cantidad deseada de nodos"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Cantidad máxima de nodos"
  type        = number
  default     = 2
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR que pueden llegar al endpoint público del clúster; se recomienda limitarlo a tu IP, por ejemplo [\"203.0.113.4/32\"]"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- ECR ---

variable "ecr_repository_names" {
  description = "Nombres de los repositorios ECR (uno por componente)"
  type        = list(string)
  default     = ["frontend", "products-service", "orders-service"]
}

variable "ecr_keep_last_images" {
  description = "Cantidad de imágenes que se conservan en cada repositorio; el resto expira"
  type        = number
  default     = 10

  validation {
    condition     = var.ecr_keep_last_images >= 1
    error_message = "Se debe conservar al menos 1 imagen."
  }
}

# --- GitHub Actions (OIDC) ---

variable "github_owner" {
  description = "Usuario u organización de GitHub dueño del repositorio store-app"
  type        = string

  validation {
    condition     = length(trimspace(var.github_owner)) > 0 && !can(regex("[*/]", var.github_owner))
    error_message = "github_owner no puede estar vacío ni contener '*' o '/'."
  }
}

variable "github_repository" {
  description = "Nombre del repositorio de GitHub que puede asumir el rol de CI"
  type        = string
  default     = "store-app"
}

variable "github_owner_id" {
  description = "Id numérico del dueño de GitHub (gh api repos/<dueño>/<repo> --jq .owner.id). Si GitHub usa el sujeto inmutable (use_immutable_subject), el sub del token lleva los ids; defínelo junto con github_repository_id. Null = formato antiguo"
  type        = number
  default     = null

  validation {
    condition     = var.github_owner_id == null || var.github_owner_id > 0
    error_message = "github_owner_id debe ser un número positivo (id de GitHub) o null."
  }
}

variable "github_repository_id" {
  description = "Id numérico del repositorio de GitHub (gh api repos/<dueño>/<repo> --jq .id). Defínelo junto con github_owner_id; null = formato antiguo del sub"
  type        = number
  default     = null

  validation {
    condition     = (var.github_owner_id == null) == (var.github_repository_id == null) && (var.github_repository_id == null || var.github_repository_id > 0)
    error_message = "Define github_owner_id y github_repository_id juntos (los dos ids numéricos de GitHub) o ninguno, y deben ser positivos."
  }
}

variable "github_branch" {
  description = "Rama del repositorio que puede asumir el rol de CI"
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Crear el proveedor OIDC de GitHub; poner false si la cuenta ya tiene uno (AWS admite uno solo por URL)"
  type        = bool
  default     = true
}
