locals {
  # Sujeto (sub) del token OIDC que el rol acepta, siempre una igualdad exacta (sin comodines).
  # Con los ids numéricos es el "sujeto inmutable" de GitHub (use_immutable_subject): resiste renombrados,
  # transferencias y repositorios recreados con el mismo nombre. Sin ids, el formato antiguo.
  github_repository_subject = (
    var.github_owner_id != null && var.github_repository_id != null
    ? "${var.github_owner}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}"
    : "${var.github_owner}/${var.github_repository}"
  )
  github_oidc_subject = "${local.github_repository_subject}:ref:refs/heads/${var.github_branch}"
}

# Proveedor OIDC de GitHub Actions. AWS admite uno solo por URL y cuenta:
# si ya existe, usa create_github_oidc_provider = false.
module "github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-oidc-provider"
  version = "6.11.1"

  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Rol que GitHub Actions asume por OIDC (sin llaves estáticas).
# Solo acepta el repositorio y la rama indicados: igualdad exacta, sin comodines.
module "github_actions_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.11.1"

  name        = "${var.cluster_name}-github-actions"
  description = "Rol de CI: permite subir imágenes a los repositorios ECR de store desde ${var.github_owner}/${var.github_repository} (${var.github_branch})"

  enable_github_oidc = true
  oidc_subjects      = [local.github_oidc_subject]

  # Permisos mínimos: solo ECR y solo sobre los repositorios del proyecto
  create_inline_policy = true
  inline_policy_permissions = {
    EcrLogin = {
      sid       = "EcrLogin"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"] # esta acción no admite un recurso específico
    }
    EcrPushPull = {
      sid = "EcrPushPull"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:DescribeImages",
        "ecr:ListImages",
      ]
      resources = [for repo in module.ecr : repo.repository_arn]
    }
  }

  # El proveedor debe existir antes de que el rol lo mencione en su política de confianza
  depends_on = [module.github_oidc_provider]
}
