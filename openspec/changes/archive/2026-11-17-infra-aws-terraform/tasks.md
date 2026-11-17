# Tasks

> Regla de este change: solo se ejecutan `terraform init -backend=false`, `terraform fmt` y `terraform validate`. NO se ejecuta `terraform apply`, `destroy` ni `plan`, ni comandos `aws` que modifiquen recursos.

## 1. Estado y andamiaje

- [x] 1.1 Marcar `infra-aws-terraform` como `in_progress` en `feature_list.json`; verificar con `./init.sh` que solo hay un change activo
- [x] 1.2 Crear `infra/terraform/versions.tf` y `providers.tf` (`required_version`, `required_providers` con `aws` 6.73.0, `default_tags` con `Project = "store"`, región por variable); verificar con `terraform init -backend=false` y `terraform validate` sin errores
- [x] 1.3 Revisar `.gitignore`: `terraform.tfvars`, `*.tfstate*`, `*.tfplan` y `.terraform/` ignorados y `.terraform.lock.hcl` no ignorado; verificar con `git check-ignore` sobre archivos de prueba creados en el directorio temporal del agente o con `git check-ignore -v` y ajustar el archivo si falta algo

## 2. Variables y etapa principal

- [x] 2.1 Escribir `variables.tf` (todas con `description`: `region`, `cluster_name`, `kubernetes_version`, `vpc_cidr`, `az_count`, `node_instance_types`, `node_min_size`, `node_desired_size`, `node_max_size`, `cluster_endpoint_public_access_cidrs`, `ecr_repository_names`, `ecr_keep_last_images`, `github_owner`, `github_repository`, `github_branch`, `create_github_oidc_provider`) y `terraform.tfvars.example` con valores de ejemplo; verificar con `terraform validate` y que `grep -c description variables.tf` coincide con el número de variables
- [x] 2.2 Escribir `vpc.tf` con `terraform-aws-modules/vpc/aws` 6.8.0 (2 AZ, subredes públicas y privadas, `single_nat_gateway`, etiquetas `kubernetes.io/role/elb` e `internal-elb`); verificar con `terraform validate` y `grep` de `single_nat_gateway = true`
- [x] 2.3 Escribir `eks.tf` con `terraform-aws-modules/eks/aws` 21.30.2 (versión de Kubernetes por variable, nodos `t3.medium` × 2 en subredes privadas, `enable_cluster_creator_admin_permissions`, CIDR del endpoint público por variable); verificar con `terraform validate`
- [x] 2.4 Escribir `ecr.tf` con `terraform-aws-modules/ecr/aws` 3.2.1 y `for_each` sobre `ecr_repository_names` (escaneo al subir, `repository_force_delete`, etiquetas mutables, política `imageCountMoreThan` con `ecr_keep_last_images`); verificar con `terraform validate` y `grep` de `repository_image_scan_on_push` e `imageCountMoreThan`
- [x] 2.5 Escribir `ebs-csi.tf`: rol con `iam-role-for-service-accounts` (`attach_ebs_csi_policy = true`, cuenta `kube-system:ebs-csi-controller-sa`) el addon `aws-ebs-csi-driver` como `aws_eks_addon` aparte (evita la dependencia circular con el OIDC del módulo EKS) y los addons `coredns`, `kube-proxy` y `vpc-cni` en el módulo EKS; verificar con `terraform validate` y `grep` de `attach_ebs_csi_policy` y `service_account_role_arn`
- [x] 2.6 Escribir `github-oidc.tf`: proveedor OIDC (opcional con `create_github_oidc_provider`) y rol de CI con sujeto exacto `repo:<github_owner>/<github_repository>:ref:refs/heads/<github_branch>`, audiencia `sts.amazonaws.com` y política mínima de ECR sobre los 3 ARN; verificar con `terraform validate`, que el sujeto no contiene `*` y que no hay acciones `eks:*` ni `iam:*`
- [x] 2.7 Escribir `outputs.tf` (`cluster_name`, `ecr_repository_urls`, `github_actions_role_arn`, más región y comando `update-kubeconfig` como texto); verificar con `terraform validate` y que no hay salidas con secretos

## 3. Etapa de Argo CD

- [x] 3.1 Crear `infra/terraform/argocd/` con `versions.tf`, `providers.tf` (`aws`, `helm` y `kubernetes` con autenticación `exec` contra `data.aws_eks_cluster`) y `variables.tf` (`region`, `cluster_name`, `argocd_namespace`, `argocd_chart_version`, todas con `description`); verificar con `terraform init -backend=false` y `terraform validate` dentro de esa carpeta
- [x] 3.2 Escribir `argocd.tf` con `helm_release` del chart `argo-cd` (repositorio oficial, versión fijada, `create_namespace`, `server.service.type = ClusterIP`, `wait`/`atomic` y tiempo de espera); verificar con `terraform validate` y que la carpeta no contiene Deployments, Services ni Applications del proyecto
- [x] 3.3 Escribir `storage.tf` con la StorageClass `gp3` por defecto (`ebs.csi.aws.com`, `type = gp3`, `WaitForFirstConsumer`, `allowVolumeExpansion`) y la anotación que quita `gp2` como predeterminada; verificar con `terraform validate` y `grep` de `WaitForFirstConsumer`
- [x] 3.4 Escribir `outputs.tf` y `terraform.tfvars.example` de la etapa (namespace y comando de `port-forward`, sin contraseñas); verificar con `terraform validate` y que no hay `password`, `token` ni `secret` en las salidas

## 4. Verificación estática

- [x] 4.1 Ejecutar `terraform fmt -recursive` y luego `terraform fmt -check -recursive` desde `infra/terraform/`; verificar que terminan sin cambios pendientes
- [x] 4.2 Ejecutar `terraform validate` en `infra/terraform/` y en `infra/terraform/argocd/`; verificar que ambos terminan con `Success! The configuration is valid.`
- [x] 4.3 Buscar secretos y llaves estáticas: `grep -rnE "AKIA|aws_secret_access_key|password *=" infra/` sin coincidencias, y `git status` sin `.terraform/`, `terraform.tfvars` ni `*.tfstate` entre los archivos nuevos; verificar que `.terraform.lock.hcl` de ambas etapas sí aparece como archivo nuevo
- [x] 4.4 Verificar convenciones: versiones exactas en cada `module` y en `required_providers`, `default_tags` con `Project = "store"`, nombres de recursos y variables en inglés y comentarios en español (revisión manual)

## 5. Documentación y cierre

- [x] 5.1 Escribir `infra/terraform/README.md` en español: requisitos, `terraform.tfvars`, pasos de `apply` (etapa 1, `aws eks update-kubeconfig`, etapa 2, lectura de la contraseña de Argo CD, `kubectl apply` de la `root-app`), pasos de `destroy` en orden inverso, tabla de costo por hora y advertencia destacada de borrar Services `LoadBalancer` y PVC antes del `destroy`; verificar que los comandos de `fmt` y `validate` documentados corren tal cual y que el README indica que `apply` y `destroy` los ejecuta el usuario
- [x] 5.2 Confirmar con `./init.sh` que sigue terminando con código 0; actualizar la estructura de `AGENTS.md` solo si cambia algo
- [x] 5.3 Ejecutar `openspec validate infra-aws-terraform` y revisar nombres en inglés y comentarios en español
- [x] 5.4 Cerrar el change: `feature_list.json` con `infra-aws-terraform` en `done` y `evidence` (fmt, validate, búsquedas estáticas; sin apply) y nueva sección en `progress.md` con siguiente paso `gitops-manifests` y la recomendación de que el usuario ejecute `terraform plan`/`apply`; verificar que `gitops-manifests` queda `pending`

## Workflow follow-up

- Archivar con `/openspec-archive-change` tras la revisión del humano.
- `terraform plan` y `terraform apply` los decide y ejecuta el humano.
- No hacer commit ni `git push` sin confirmación.
