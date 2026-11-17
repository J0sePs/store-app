## ADDED Requirements

### Requirement: Contrato con la CI

Cada componente con imagen (`frontend`, `products-service`, `orders-service`) SHALL poder actualizarse con `kustomize edit set image <nombre>=<repositorio ECR>:<tag>` ejecutado dentro de `apps/<nombre>`, que modifica únicamente el bloque `images` de su `kustomization.yaml`. El tag SHALL ser el SHA corto del commit. La CI NO SHALL usar `kubectl apply`.

#### Scenario: Actualización por la CI
- **WHEN** se ejecuta `kustomize edit set image frontend=<ecr>/frontend:abc1234` en `apps/frontend`
- **THEN** solo cambia el bloque `images` del `kustomization.yaml` y la construcción muestra la imagen y `APP_VERSION` `abc1234`

#### Scenario: Imágenes de marcador
- **WHEN** aún no ha corrido la CI
- **THEN** las imágenes apuntan a una cuenta de ECR de marcador con un tag obvio (`0000000`) que la CI reemplaza por completo

### Requirement: README operativo en español

`store-gitops/README.md` SHALL explicar en español: la estructura del repositorio; los comandos `kubectl create namespace store` y `kubectl create secret generic` para las dos bases (con una contraseña generada en el momento, sin escribirla en ningún archivo); cómo registrar el repositorio en Argo CD (público, y privado con un token que no se guarda en git); cómo aplicar la `root-app`; cómo entrar a la UI de Argo CD (contraseña inicial y `port-forward`); cómo obtener la URL del frontend; cómo actualiza la CI las imágenes; y cómo limpiar los PVC y el balanceador antes de `terraform destroy`.

#### Scenario: Comandos de Secrets
- **WHEN** se lee la sección de Secrets
- **THEN** incluye `kubectl create secret generic products-db-credentials` y `orders-db-credentials` con `POSTGRES_PASSWORD` y `DATABASE_URL`, generando la contraseña con un comando

#### Scenario: Registro del repositorio y UI
- **WHEN** se lee el README
- **THEN** explica el registro del repo en Argo CD y el acceso a la UI con `kubectl port-forward` y el Secret `argocd-initial-admin-secret`

#### Scenario: Orden de pasos
- **WHEN** se sigue el README
- **THEN** el orden es: namespace y Secrets, `root-app`, comprobar la sincronización y abrir el frontend

### Requirement: Sin secretos ni estado local en git

El repositorio SHALL tener un `.gitignore` que ignore archivos de secretos y variables locales, y NO SHALL contener tokens, contraseñas ni credenciales de AWS.

#### Scenario: Búsqueda de secretos
- **WHEN** se buscan `AKIA`, `ghp_`, `password:` y `kind: Secret` en el repositorio
- **THEN** no hay coincidencias de valores reales

### Requirement: Revisión previa a la sincronización

Antes de pedir a Argo CD que sincronice, los manifiestos SHALL poder revisarse sin un clúster: construirse con `kubectl kustomize` y pasar comprobaciones estáticas (probes, recursos, `gp3`, tipos de Service, política de las Applications).

#### Scenario: Comprobaciones sin clúster
- **WHEN** se ejecutan las comprobaciones de `tasks.md` sobre `store-gitops`
- **THEN** todas pasan sin acceso a ningún clúster
