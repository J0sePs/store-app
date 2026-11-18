# Tasks

> Los workflows solo se ejecutan en GitHub. Aquí se escriben y se revisan con `actionlint` y con una prueba local del script. No se crean secrets ni se ejecuta nada contra AWS ni contra los repositorios remotos. Los commits y el `git push` los hace el humano.

## 1. Estado y andamiaje

- [x] 1.1 Marcar `ci-github-actions` como `in_progress` en `feature_list.json`; verificar con `./init.sh` que solo hay un change activo
- [x] 1.2 Crear `.github/workflows/` y `.github/scripts/`, y compilar `actionlint` v1.7.12 y el CLI de Kustomize 5.8.3 en el directorio temporal del agente (`go install`); verificar con `actionlint -version` y `kustomize version`
- [x] 1.3 Descargar el tarball de Kustomize 5.8.3 para `linux/amd64` desde `kubernetes-sigs/kustomize` y calcular su sha256, comparándolo con el `checksums.txt` de la misma release; verificar que coinciden y anotar el valor para el workflow

## 2. Script de actualización de gitops

- [x] 2.1 Escribir `.github/scripts/update-gitops.sh` (variables `COMPONENT`, `ECR_REGISTRY`, `SHORT_SHA`, `GITOPS_DIR`; `set -euo pipefail`; validación de entradas; `kustomize edit set image`; verificación de `APP_VERSION` e imagen con `kustomize build`; commit `deploy(<servicio>): <sha>` como `github-actions[bot]`; sin cambios = salida correcta; push con `pull --rebase`, 5 intentos con espera creciente y reinicio desde `origin/main` si el rebase tiene conflicto; mensajes en español); verificar con `bash -n` y `shellcheck` si está disponible
- [x] 2.2 Probar el caso feliz en local: remoto git temporal (repositorio desnudo clonado de `../store-gitops`) y copia de trabajo; verificar que el script crea el commit `deploy(frontend): abc1234`, que el remoto lo recibe, que solo cambió el bloque `images` y que `APP_VERSION` es `abc1234`
- [x] 2.3 Probar remoto adelantado y conflicto: otro clon sube un commit a otro componente (rebase limpio) y otro al mismo `kustomization.yaml` (conflicto); verificar que ambos escenarios terminan con el SHA del script en el remoto y sin perder el commit ajeno
- [x] 2.4 Probar sin cambios, versión incorrecta y reintentos agotados: ejecutar dos veces el mismo SHA (la segunda sin commit y con código 0), forzar un `APP_VERSION` que no coincide (falla antes del commit) y un remoto que rechaza los push (falla tras 5 intentos con mensaje en español); verificar los códigos de salida y que el remoto no cambió en los fallos

## 3. Workflow reutilizable

- [x] 3.1 Escribir `.github/workflows/_deploy-component.yml` (`workflow_call` con entradas `component`, `aws-role-arn`, `aws-region`, `build-args` y el secret `GITOPS_TOKEN`): job `build-and-push` (OIDC, login a ECR, buildx, build y push con la etiqueta de 7 caracteres, `provenance: false`, comprobación con `aws ecr describe-images`, salidas `short-sha` y `registry`) y job `update-gitops` (`needs`, concurrencia `gitops-update`, checkout de `${{ github.repository_owner }}/store-gitops` con `GITOPS_TOKEN`, Kustomize descargado con sha256 verificado, llamada al script con variables de entorno); verificar con `actionlint` sin errores
- [x] 3.2 Revisar la seguridad del reutilizable con comprobaciones estáticas: `permissions` explícitos (`contents: read` y `id-token: write` solo en `build-and-push`), `GITOPS_TOKEN` referenciado solo en `update-gitops`, ningún `${{ }}` con datos del usuario dentro de `run`, sin `latest`, sin `kubectl` y sin llaves de AWS; verificar con un script de Python que lo comprueba y termina sin fallos

## 4. Workflows por componente

- [x] 4.1 Escribir `.github/workflows/frontend.yml` (`push` a `main` con `paths: frontend/**`, `workflow_dispatch`, concurrencia `deploy-frontend`, job `test` con `npm ci`, lint y tests, y job `deploy` que llama al reutilizable con `needs: test` y `APP_VERSION` como build-arg); verificar con `actionlint`
- [x] 4.2 Escribir `.github/workflows/products-service.yml` (`paths: products-service/**`, job `test` con `requirements-dev.txt`, `ruff check`, `ruff format --check` y `pytest`, y `deploy`); verificar con `actionlint`
- [x] 4.3 Escribir `.github/workflows/orders-service.yml` (`paths: orders-service/**`, job `test` con `setup-go` desde `go.mod`, `gofmt -l`, `go vet` y `go test`, y `deploy`); verificar con `actionlint`
- [x] 4.4 Comprobar con Python los criterios de los specs sobre los tres workflows: disparo solo en `main` con `paths` de su carpeta y sin los archivos de workflow, `needs` entre jobs, permisos, versiones mayores en cada `uses:`, y que los comandos de test coinciden con los de `AGENTS.md`; verificar que todos pasan

## 5. Documentación y cierre

- [x] 5.1 Añadir al `README.md` raíz la sección "CI/CD con GitHub Actions" en español: flujo, tabla de secrets y variables (`GITOPS_TOKEN` con cómo crearlo, `AWS_ROLE_ARN`, `AWS_REGION`), lista de comprobación del primer despliegue, ejecución manual, protección de rama en `store-gitops` y advertencia de crear los secrets antes del primer push; verificar que los comandos documentados son válidos y que no hay valores reales
- [x] 5.2 Ejecutar `actionlint` sobre todo `.github/workflows/`, `./init.sh` y `openspec validate ci-github-actions`; verificar que los tres terminan sin errores y revisar nombres en inglés y mensajes en español
- [x] 5.3 Cerrar el change: `feature_list.json` con `ci-github-actions` en `done` y `evidence`, nueva sección en `progress.md` con el orden de despliegue real y siguiente paso `demo-visible-change`; verificar que `demo-visible-change` queda `pending`

## Workflow follow-up

- Archivar con `/openspec-archive-change` tras la revisión del humano.
- Crear `GITOPS_TOKEN` y `AWS_ROLE_ARN` en GitHub y el primer `git push` de `store-app` los hace el humano.
