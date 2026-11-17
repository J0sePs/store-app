# Un repositorio ECR por componente (la CI sube aquí las imágenes con el SHA corto como etiqueta)
module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "3.2.1"

  for_each = toset(var.ecr_repository_names)

  repository_name = each.key

  # Escanea cada imagen al subirla
  repository_image_scan_on_push = true

  # Etiquetas mutables: un reintento de CI con el mismo SHA no se rechaza.
  # La etiqueta "latest" está prohibida por la regla del proyecto y se controla en CI.
  repository_image_tag_mutability = "MUTABLE"

  # Permite que "terraform destroy" borre repositorios que aún tienen imágenes
  repository_force_delete = true

  # Conserva solo las últimas N imágenes y expira el resto
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar solo las últimas ${var.ecr_keep_last_images} imágenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_keep_last_images
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
