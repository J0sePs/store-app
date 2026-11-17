## ADDED Requirements

### Requirement: Variables, salidas y ejemplo de valores

Cada etapa SHALL tener `variables.tf` (todas las variables con `description`), `outputs.tf` y `terraform.tfvars.example`. La etapa principal SHALL exponer como salidas el nombre del clúster, las URLs de los tres repositorios ECR y el ARN del rol de CI. `terraform.tfvars.example` SHALL usar valores de ejemplo, sin datos reales.

#### Scenario: Salidas de la etapa principal
- **WHEN** se ejecuta `terraform output` tras el `apply`
- **THEN** muestra `cluster_name`, las URLs de ECR (`frontend`, `products-service`, `orders-service`) y `github_actions_role_arn`

#### Scenario: Variables documentadas
- **WHEN** se revisa `variables.tf` de cada etapa
- **THEN** todas las variables tienen `description`

#### Scenario: Usuario de GitHub obligatorio
- **WHEN** se ejecuta `terraform plan` sin definir `github_owner`
- **THEN** Terraform pide el valor o falla indicando que falta

### Requirement: Etiquetas y proveedores

El proveedor `aws` SHALL definir `default_tags` con `Project = "store"`. Los módulos y proveedores SHALL tener versiones fijadas y `.terraform.lock.hcl` SHALL versionarse. Los recursos y variables SHALL nombrarse en inglés y los comentarios SHALL estar en español.

#### Scenario: Etiqueta del proyecto
- **WHEN** se revisa la configuración del proveedor `aws`
- **THEN** `default_tags` contiene `Project = "store"`

#### Scenario: Versiones fijadas
- **WHEN** se revisan los bloques `module` y `required_providers`
- **THEN** cada uno tiene una versión explícita

### Requirement: Secretos y estado fuera de git

El repositorio SHALL ignorar `terraform.tfvars`, `*.tfstate*`, `*.tfplan` y `.terraform/`, y NO SHALL contener llaves de acceso de AWS, tokens ni contraseñas.

#### Scenario: Archivos ignorados
- **WHEN** se ejecuta `git check-ignore` sobre `terraform.tfvars`, `terraform.tfstate` y `.terraform/`
- **THEN** los tres están ignorados y `terraform.tfvars.example` y `.terraform.lock.hcl` no lo están

#### Scenario: Sin llaves estáticas
- **WHEN** se busca `AKIA` y `aws_secret_access_key` en `infra/`
- **THEN** no hay coincidencias

### Requirement: README operativo

`infra/terraform/README.md` SHALL estar en español y explicar: requisitos, los pasos de `apply` (en orden, con la etapa de Argo CD) y de `destroy` (en orden inverso), el costo estimado por hora desglosado por componente, y una advertencia destacada de eliminar los Services de tipo `LoadBalancer` (y los PVC) antes de hacer `destroy`, porque dejan balanceadores y volúmenes EBS huérfanos que bloquean el borrado de la VPC y siguen cobrando.

#### Scenario: Pasos y costo
- **WHEN** se lee el README
- **THEN** incluye los comandos de `apply` y `destroy` de ambas etapas y una tabla de costo por hora con el total aproximado

#### Scenario: Advertencia de LoadBalancer
- **WHEN** se lee la sección de `destroy`
- **THEN** una advertencia explica que hay que borrar los Services `LoadBalancer` y los PVC antes, con los comandos `kubectl` para hacerlo

#### Scenario: Confirmación humana
- **WHEN** se lee el README
- **THEN** indica que `apply` y `destroy` los ejecuta el usuario y que ningún agente debe hacerlo sin confirmación
