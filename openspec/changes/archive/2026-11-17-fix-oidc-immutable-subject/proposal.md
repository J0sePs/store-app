## Why

El primer build de los 3 componentes falló en los tres workflows en el paso `Configure AWS credentials (OIDC)` con `Not authorized to perform sts:AssumeRoleWithWebIdentity`. La causa es que GitHub tiene activado en el repositorio el **sujeto inmutable** (`use_immutable_subject: true`): el claim `sub` del token lleva los ids numéricos del dueño y del repositorio (`repo:J0sePs@146149882/store-app@1461989222:ref:refs/heads/main`), y la política de confianza del rol de CI exige el formato antiguo (`repo:J0sePs/store-app:ref:refs/heads/main`). Hay que corregirla para poder publicar imágenes.

## What Changes

- Terraform (`infra/terraform`): dos variables nuevas, `github_owner_id` y `github_repository_id` (números, por defecto `null`; deben definirse las dos o ninguna). Si están definidas, el sujeto de la política de confianza es `repo:<dueño>@<id del dueño>/<repo>@<id del repo>:ref:refs/heads/<rama>`; si no, se mantiene el formato antiguo. Sigue siendo una **igualdad exacta, sin comodines**, y solo se acepta un formato a la vez.
- `terraform.tfvars` local con los ids reales y `terraform.tfvars.example` con marcadores y el comando para obtenerlos.
- Spec `github-oidc-access` modificado (requisito del rol de CI) y README (`infra/terraform` y raíz): cómo conocer el formato del `sub` y los ids, y una entrada de problemas frecuentes para este error.
- `terraform plan` que debe cambiar **solo** la política de confianza del rol, en el sitio (sin reemplazo y sin costo). El `apply` espera tu confirmación.
- Después del `apply`: relanzar los 3 workflows y comprobar que el paso OIDC pasa.

Los workflows no cambian. No hay cambios **BREAKING**.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `github-oidc-access`: el sujeto de la política de confianza admite el formato inmutable de GitHub (con ids) además del antiguo, siempre exacto.

## Impact

- **Componentes afectados:** `infra/terraform/` (`variables.tf`, `github-oidc.tf`, `terraform.tfvars.example`) y documentación. Cambia en AWS solo la política de confianza del rol `store-eks-github-actions-*` (modificación en el sitio, sin costo).
- **Seguridad:** no se ensancha el acceso; el sujeto sigue acotado a un repositorio y una rama. Con ids, además, resiste el *repo-jacking* (un repositorio renombrado o transferido no hereda el acceso).
- **Fuera de alcance:** cambiar los workflows, desactivar el sujeto inmutable en GitHub, crear el proveedor OIDC de nuevo y aplicar el Application raíz de Argo CD.
- **Archivos del repo:** `feature_list.json` y `progress.md`.
