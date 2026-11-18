## ADDED Requirements

### Requirement: Actualización de store-gitops solo tras un push correcto

El job `update-gitops` SHALL depender de `build-and-push` y ejecutarse únicamente si este terminó con éxito. Si falla el build, el push a ECR o la verificación de la etiqueta, `store-gitops` NO SHALL modificarse.

#### Scenario: Push correcto
- **WHEN** `build-and-push` termina con éxito
- **THEN** `update-gitops` se ejecuta

#### Scenario: Push fallido
- **WHEN** `build-and-push` falla
- **THEN** `update-gitops` no se ejecuta y `store-gitops` no cambia

### Requirement: Checkout de store-gitops con GITOPS_TOKEN

El job SHALL hacer checkout del repositorio `<dueño>/store-gitops` (el mismo dueño del repositorio actual, rama `main`) usando el secret `GITOPS_TOKEN`. Ese token SHALL usarse solo en este job y no SHALL aparecer en logs ni en archivos.

#### Scenario: Repositorio correcto
- **WHEN** corre el job `update-gitops`
- **THEN** el checkout es de `store-gitops` en `main`, autenticado con `GITOPS_TOKEN`

#### Scenario: Token acotado
- **WHEN** se revisan los jobs
- **THEN** `GITOPS_TOKEN` solo se referencia en `update-gitops`

### Requirement: Actualización de la imagen con kustomize edit

El job SHALL usar un binario de Kustomize de versión fijada y verificada con su suma sha256, entrar en `apps/<componente>` y ejecutar `kustomize edit set image <componente>=<registro ECR>/<componente>:<sha corto>`. NO SHALL usar `kubectl apply` ni editar archivos con `sed`.

#### Scenario: Bloque images
- **WHEN** se actualiza el componente `frontend` con el SHA `abc1234`
- **THEN** el bloque `images` de `apps/frontend/kustomization.yaml` queda con `newName` del ECR y `newTag: abc1234`

#### Scenario: Binario verificado
- **WHEN** el job descarga Kustomize
- **THEN** comprueba la suma sha256 esperada y falla si no coincide

### Requirement: APP_VERSION igual al SHA

Tras la edición, el job SHALL construir el componente (`kustomize build`) y comprobar que `APP_VERSION` del Deployment vale el SHA corto y que la imagen termina en `:<sha corto>`. Si no coincide, el job SHALL fallar y NO SHALL hacer commit. `APP_VERSION` no se edita a mano: Kustomize la copia del tag (ver `k8s-workloads`).

#### Scenario: Versión correcta
- **WHEN** la imagen se actualiza a `abc1234`
- **THEN** `kustomize build` muestra `APP_VERSION` igual a `abc1234` y el job continúa

#### Scenario: Versión incorrecta
- **WHEN** `APP_VERSION` no coincide con el SHA tras la edición
- **THEN** el job falla antes del commit

### Requirement: Commit y push con reintentos

Si la edición produjo cambios, el job SHALL hacer commit con el mensaje `deploy(<servicio>): <sha corto>` y autor `github-actions[bot]`, y SHALL hacer push a `main` con `git pull --rebase` y hasta 5 intentos con espera creciente. Si el rebase tiene conflicto, SHALL descartar el intento, volver al estado remoto y repetir la edición. Si no hay cambios (mismo SHA), SHALL terminar sin commit y sin error. Los mensajes del script SHALL estar en español.

#### Scenario: Commit
- **WHEN** hay cambios y el push funciona
- **THEN** `store-gitops` recibe un commit `deploy(frontend): abc1234` en `main`

#### Scenario: Remoto adelantado
- **WHEN** otro workflow subió un commit a `store-gitops` mientras este corría
- **THEN** el job hace `pull --rebase` y el push funciona sin perder ninguno de los dos commits

#### Scenario: Conflicto en el mismo archivo
- **WHEN** el remoto cambió el mismo `kustomization.yaml` y el rebase entra en conflicto
- **THEN** el job reinicia desde el remoto, repite la edición y el resultado final tiene el SHA de este workflow

#### Scenario: Sin cambios
- **WHEN** el SHA ya está en `store-gitops`
- **THEN** el job termina correctamente sin hacer commit

#### Scenario: Agotados los intentos
- **WHEN** el push falla 5 veces seguidas
- **THEN** el job falla con un mensaje en español

### Requirement: Un solo escritor a la vez en store-gitops

Los jobs `update-gitops` de todos los workflows SHALL compartir un grupo de concurrencia, para que no escriban en `store-gitops` al mismo tiempo, sin cancelar las ejecuciones en curso.

#### Scenario: Dos componentes a la vez
- **WHEN** `frontend` y `products-service` llegan a `update-gitops` simultáneamente
- **THEN** uno espera al otro y ambos commits quedan en `store-gitops`
