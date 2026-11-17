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

La infraestructura SHALL crear un rol IAM que GitHub Actions asume mediante OIDC y cuya política de confianza solo acepta el sujeto `repo:<github_owner>/<github_repository>:ref:refs/heads/<github_branch>` (por defecto repositorio `store-app` y rama `main`) y la audiencia `sts.amazonaws.com`. El rol NO SHALL usar llaves de acceso estáticas ni comodines en el sujeto.

#### Scenario: Rama main
- **WHEN** un workflow de `<usuario>/store-app` corre en la rama `main` y pide asumir el rol
- **THEN** AWS entrega credenciales temporales

#### Scenario: Otra rama
- **WHEN** el workflow corre en la rama `feature-x`
- **THEN** AWS rechaza asumir el rol

#### Scenario: Otro repositorio
- **WHEN** un workflow de otro repositorio intenta asumir el rol
- **THEN** AWS lo rechaza

#### Scenario: Sin comodines
- **WHEN** se revisa la política de confianza
- **THEN** la condición del sujeto es una igualdad exacta, sin `*`

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
