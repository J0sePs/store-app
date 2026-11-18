## ADDED Requirements

### Requirement: Un workflow por componente con filtro de rutas

El repositorio SHALL tener `.github/workflows/frontend.yml`, `products-service.yml` y `orders-service.yml`. Cada uno SHALL dispararse con un `push` a la rama `main` solo cuando cambien archivos de la carpeta de su componente (`frontend/**`, `products-service/**` u `orders-service/**`), y también con `workflow_dispatch`. Los propios archivos de workflow NO SHALL estar en el filtro de rutas, para que subirlos no dispare despliegues.

#### Scenario: Cambio en un componente
- **WHEN** se hace push a `main` con cambios solo en `products-service/`
- **THEN** corre `products-service.yml` y no corren `frontend.yml` ni `orders-service.yml`

#### Scenario: Cambio fuera de los componentes
- **WHEN** se hace push a `main` con cambios solo en `docs/` o en `.github/`
- **THEN** no corre ningún workflow de componente

#### Scenario: Otra rama
- **WHEN** se hace push a una rama distinta de `main`
- **THEN** no corre ningún workflow

#### Scenario: Ejecución manual
- **WHEN** se lanza un workflow con `workflow_dispatch`
- **THEN** ejecuta los mismos jobs sobre la rama elegida, y el job de AWS falla si no es `main` porque el rol solo confía en esa rama

### Requirement: Tests antes de publicar

Cada workflow SHALL ejecutar primero un job `test` con los comandos del componente y SHALL no construir ni publicar nada si falla. `frontend`: `npm ci`, `npm run lint` y `npm test -- --watch=false`. `products-service`: instalar `requirements-dev.txt`, `ruff check`, `ruff format --check` y `pytest`. `orders-service`: `gofmt -l` sin salida, `go vet ./...` y `go test ./...`.

#### Scenario: Tests fallan
- **WHEN** falla un test del componente
- **THEN** los jobs `build-and-push` y `update-gitops` no se ejecutan

#### Scenario: Lint falla
- **WHEN** el formato o el lint del componente no pasan
- **THEN** el job `test` falla y no se publica ninguna imagen

### Requirement: Autenticación en AWS por OIDC

La publicación SHALL autenticarse con `aws-actions/configure-aws-credentials` asumiendo el rol indicado en la variable `AWS_ROLE_ARN`, con el permiso `id-token: write` solo en los jobs que lo necesitan. NO SHALL usarse llaves de acceso de AWS ni secrets con credenciales de AWS.

#### Scenario: Rol por OIDC
- **WHEN** corre el job `build-and-push` en `main`
- **THEN** obtiene credenciales temporales por OIDC y no hay ninguna llave estática en los workflows

#### Scenario: Permisos mínimos
- **WHEN** se revisan los permisos de los workflows
- **THEN** por defecto solo tienen `contents: read` y solo `build-and-push` añade `id-token: write`

### Requirement: Imagen con etiqueta igual al SHA corto

El job `build-and-push` SHALL construir la imagen del componente con el contexto de su carpeta, para `linux/amd64`, y publicarla en el repositorio ECR del componente (`frontend`, `products-service`, `orders-service`) con una única etiqueta: los 7 primeros caracteres del SHA del commit. NO SHALL publicar la etiqueta `latest`. El frontend SHALL recibir ese SHA como `APP_VERSION` al construir. Antes de terminar, el job SHALL comprobar con `aws ecr describe-images` que la etiqueta existe en el repositorio.

#### Scenario: Etiqueta
- **WHEN** el commit es `abc1234def5678`
- **THEN** la imagen se publica como `<registro>/<componente>:abc1234`

#### Scenario: Sin latest
- **WHEN** se revisan las etiquetas que publica el workflow
- **THEN** ninguna es `latest`

#### Scenario: Versión del frontend
- **WHEN** se construye la imagen del frontend en el commit `abc1234def5678`
- **THEN** recibe `APP_VERSION=abc1234` y `/health` y `/version.json` devuelven `abc1234`

#### Scenario: Verificación del push
- **WHEN** el push a ECR termina
- **THEN** el job confirma la etiqueta en ECR y falla si no aparece

### Requirement: Un solo despliegue a la vez por componente

Cada workflow SHALL usar un grupo de concurrencia por componente sin cancelar las ejecuciones en curso, para que dos pushes seguidos al mismo componente se procesen en orden.

#### Scenario: Dos pushes seguidos
- **WHEN** llegan dos pushes al mismo componente con segundos de diferencia
- **THEN** la segunda ejecución espera a que termine la primera
