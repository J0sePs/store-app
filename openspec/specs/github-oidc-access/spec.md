# github-oidc-access Specification

## Purpose
Acceso de GitHub Actions a AWS por OIDC, sin llaves estáticas, con un rol limitado a un repositorio y una rama y con permisos de push solo a los tres repositorios ECR.

## Requirements

### Requirement: Proveedor OIDC de GitHub

La infraestructura SHALL crear el proveedor OIDC de GitHub Actions (`token.actions.githubusercontent.com`) con la audiencia `sts.amazonaws.com`. Como AWS permite un solo proveedor por URL en la cuenta, SHALL poder omitirse con `create_github_oidc_provider = false` para reutilizar el existente.

#### Scenario: Proveedor creado
- **WHEN** se aplican las variables por defecto
- **THEN** existe un proveedor OIDC con URL `https://token.actions.githubusercontent.com` y audiencia `sts.amazonaws.com`

#### Scenario: Proveedor ya existente
- **WHEN** `create_github_oidc_provider = false`
- **THEN** no se crea otro proveedor y el rol usa el existente

### Requirement: Rol de CI limitado al repositorio y la rama

La infraestructura SHALL crear un rol IAM que GitHub Actions asume mediante OIDC y cuya política de confianza acepta exactamente un sujeto y la audiencia `sts.amazonaws.com`. Si se definen `github_owner_id` y `github_repository_id` (los ids numéricos del dueño y del repositorio, que usa el sujeto inmutable de GitHub), el sujeto SHALL ser `repo:<github_owner>@<github_owner_id>/<github_repository>@<github_repository_id>:ref:refs/heads/<github_branch>`; si no se definen, SHALL ser `repo:<github_owner>/<github_repository>:ref:refs/heads/<github_branch>`. Ambas variables SHALL definirse juntas o ninguna. Por defecto el repositorio es `store-app` y la rama `main`. El rol NO SHALL usar llaves de acceso estáticas ni comodines en el sujeto.

#### Scenario: Rama main
- **WHEN** un workflow de `<usuario>/store-app` corre en la rama `main` y pide asumir el rol
- **THEN** AWS entrega credenciales temporales

#### Scenario: Rama main con sujeto inmutable
- **WHEN** el repositorio usa el sujeto inmutable, los ids están definidos y un workflow de `<usuario>/store-app` corre en la rama `main`
- **THEN** AWS entrega credenciales temporales

#### Scenario: Rama main con sujeto antiguo
- **WHEN** los ids no están definidos, el repositorio usa el formato antiguo y el workflow corre en `main`
- **THEN** AWS entrega credenciales temporales

#### Scenario: Otra rama
- **WHEN** el workflow corre en la rama `feature-x`
- **THEN** AWS rechaza asumir el rol

#### Scenario: Otro repositorio
- **WHEN** un workflow de otro repositorio intenta asumir el rol
- **THEN** AWS lo rechaza

#### Scenario: Ids incorrectos
- **WHEN** `github_repository_id` no coincide con el id real del repositorio (por ejemplo, un repositorio con el mismo nombre recreado)
- **THEN** AWS rechaza asumir el rol

#### Scenario: Sin comodines
- **WHEN** se revisa la política de confianza
- **THEN** la condición del sujeto es una igualdad exacta con un único valor, sin `*`

#### Scenario: Ids incompletos
- **WHEN** se define `github_owner_id` pero no `github_repository_id` (o al revés)
- **THEN** `terraform plan` falla con un mensaje en español que pide definir los dos ids o ninguno

#### Scenario: Plan sin reemplazo
- **WHEN** se cambia el sujeto de un rol ya creado y se ejecuta `terraform plan`
- **THEN** el plan modifica la política de confianza en el sitio y no reemplaza ni destruye el rol

### Requirement: Permisos de push a los tres repositorios

El rol SHALL poder autenticarse en ECR (`ecr:GetAuthorizationToken`) y SHALL tener permisos de subida (`BatchCheckLayerAvailability`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload`, `PutImage`) y de consulta de imágenes únicamente sobre los ARN de los tres repositorios. NO SHALL tener permisos sobre el clúster ni administrativos.

#### Scenario: Push a un repositorio del proyecto
- **WHEN** el rol sube una imagen a `products-service`
- **THEN** la operación está permitida

#### Scenario: Recurso ajeno
- **WHEN** el rol intenta subir una imagen a un repositorio que no es de los tres
- **THEN** la operación está denegada

#### Scenario: Sin permisos sobre EKS
- **WHEN** se revisan las políticas del rol
- **THEN** no hay acciones `eks:*` ni `iam:*`
