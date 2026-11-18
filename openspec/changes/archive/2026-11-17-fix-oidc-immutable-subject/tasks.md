# Tasks

> Reglas: el `terraform apply` modifica AWS y espera la confirmación del usuario (se ejecuta solo después de su OK). `terraform fmt`, `validate` y `plan` son de lectura. Ningún valor secreto interviene: los ids de GitHub no son secretos. Commits y `git push` los hace el humano.

## 1. Estado

- [x] 1.1 Añadir `fix-oidc-immutable-subject` a `feature_list.json` como `change-9` (dependencias `change-4` y `change-6`) en estado `in_progress`; verificar con `./init.sh` que solo hay un change activo

## 2. Terraform

- [x] 2.1 Añadir `github_owner_id` y `github_repository_id` (`number`, por defecto `null`, con `description` y validación de "las dos o ninguna" con mensaje en español) a `variables.tf`, y calcular el sujeto en un `local` de `github-oidc.tf` usado por `oidc_subjects`; verificar con `terraform fmt -check` y `terraform validate`
- [x] 2.2 Probar la validación y el cálculo sin tocar AWS: `terraform plan` con un solo id definido debe fallar con el mensaje en español, y el sujeto calculado (con `terraform console` o el plan) debe ser exactamente `J0sePs@146149882/store-app@1461989222:ref:refs/heads/main` con los dos ids y `J0sePs/store-app:ref:refs/heads/main` sin ellos; verificar que ninguno contiene `*`
- [x] 2.3 Definir los ids reales en `terraform.tfvars` (ignorado por git) y dejar marcadores y el comando `gh api` en `terraform.tfvars.example`; verificar con `git check-ignore terraform.tfvars` y que `terraform validate` sigue pasando

## 3. Plan

- [x] 3.1 Ejecutar `terraform plan -input=false -out=plan.tfplan` en `infra/terraform`; verificar que termina con código 0 y que `plan.tfplan` está ignorado por git
- [x] 3.2 Analizar `terraform show -json plan.tfplan`; verificar que hay exactamente 1 cambio, una modificación **en el sitio** de la política de confianza del rol de CI (sin reemplazo, sin destroy), que el `sub` nuevo es `repo:J0sePs@146149882/store-app@1461989222:ref:refs/heads/main` con un único valor y sin `*`, y que `aud` e `iss` no cambian; si aparece cualquier otra acción, detenerse y avisar

## 4. Documentación

- [x] 4.1 Actualizar `infra/terraform/README.md` (tabla de variables, viñeta de seguridad con el formato del sujeto y una entrada de "Problemas frecuentes" para `Not authorized to perform sts:AssumeRoleWithWebIdentity`) y la sección de CI del `README.md` raíz (cómo comprobar el formato del `sub` y obtener los ids); verificar que los comandos documentados son válidos (`bash -n`) y que no hay valores secretos

## 5. Cierre del código y espera de confirmación

- [x] 5.1 Ejecutar `./init.sh`, `openspec validate fix-oidc-immutable-subject`, `terraform fmt -check -recursive` y `terraform validate`; verificar que todo termina sin errores
- [x] 5.2 Actualizar `progress.md` y `feature_list.json` con el estado (código y plan listos, `apply` pendiente de OK) y presentar al usuario el resumen del plan para pedir su confirmación; verificar que el resumen indica que el cambio es solo la política de confianza, en el sitio y sin costo

## 6. Aplicación en AWS y verificación (solo tras el OK del usuario)

- [x] 6.1 Ejecutar `terraform apply plan.tfplan` y comprobar la política real con `aws iam get-role` (un único `sub`, el nuevo, y `aud`/`iss` intactos); verificar que el apply termina con `1 changed` y sin altas ni bajas
- [x] 6.2 Relanzar los 3 workflows con `gh workflow run <archivo> --ref main` y seguirlos con `gh`; verificar que el paso `Configure AWS credentials (OIDC)` pasa en los tres. Si falla otro paso, mostrar el log antes de corregir

## Workflow follow-up

- Archivar con `/openspec-archive-change` cuando el login OIDC funcione.
- Después del build correcto: imágenes en ECR, commits `deploy(<servicio>): <sha>` en `store-gitops` y, solo con el OK del usuario, el Application raíz de Argo CD.
