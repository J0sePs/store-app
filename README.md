# store-app

Sistema de microservicios (frontend Angular, `products-service` en FastAPI, `orders-service` en Go) desplegado en AWS EKS con GitOps. Las reglas completas están en `AGENTS.md`.

## Flujo de trabajo para agentes y personas

Cada funcionalidad se hace con un change de OpenSpec (`propose` → revisión → `apply` → `archive`). El estado vive en archivos de la raíz, no en el chat:

| Archivo | Para qué sirve |
|---|---|
| `feature_list.json` | Un registro por change: `id`, `name`, `description`, `status` (`pending` / `in_progress` / `done`) y `evidence`. Solo un change `in_progress` a la vez. |
| `progress.md` | Bitácora en español. Al cerrar un change se agrega qué se hizo, la evidencia y el siguiente paso. |
| `init.sh` | Verifica herramientas y corre los tests de los componentes que existan. |

**Al iniciar sesión:** lee `progress.md` y `feature_list.json`, y ejecuta:

```bash
./init.sh
```

Muestra la versión de `git`, `docker`, `node`, `python3`, `go`, `terraform`, `aws`, `kubectl` y `openspec`, avisa las que falten y corre los tests de `products-service`, `orders-service` y `frontend` si ya existen. Es de solo lectura (no hace `terraform apply`, `git push` ni `kubectl apply`). Con `SKIP_TESTS=1 ./init.sh` se omiten los tests. Sale con código 1 si algún test falla o si `feature_list.json` es inválido.

**Al cerrar un change:** actualiza `status` y `evidence` en `feature_list.json` y agrega una sección a `progress.md`.

## Ejecutar todo en local

Levanta el frontend, los dos servicios y sus bases de datos con `docker compose` (no necesita AWS):

```bash
cp .env.example .env        # contraseñas y versiones de ejemplo; .env no se sube a git
docker compose up --build
```

Abre http://localhost (cambia el puerto con `FRONTEND_PORT` en `.env` si el 80 está ocupado). Solo el frontend se publica al host; nginx enruta `/api/products` y `/api/orders` a cada servicio. Para detener todo y borrar los datos: `docker compose down -v`.

## CI/CD con GitHub Actions

Cada push a `main` que cambie un componente lo prueba, publica su imagen en ECR y le dice a `store-gitops` qué versión desplegar. Después Argo CD hace el resto.

```
push a main (cambia frontend/, products-service/ u orders-service/)
  → job test: lint y tests del componente
  → job build-and-push: login a AWS por OIDC, build, push a ECR con tag = SHA corto y comprobación en ECR
  → job update-gitops (solo si el push salió bien): kustomize edit set image, comprobación de APP_VERSION,
    commit "deploy(<servicio>): <sha>" y push a store-gitops (con pull --rebase y reintentos)
  → Argo CD pasa de OutOfSync a Synced y hace el rolling update
```

| Workflow | Se dispara con cambios en | Tests |
|---|---|---|
| `.github/workflows/frontend.yml` | `frontend/**` | `npm run lint`, `npm test -- --watch=false` |
| `.github/workflows/products-service.yml` | `products-service/**` | `ruff check`, `ruff format --check`, `pytest` |
| `.github/workflows/orders-service.yml` | `orders-service/**` | `gofmt -l`, `go vet ./...`, `go test ./...` |

Los tres llaman a `.github/workflows/_deploy-component.yml` (build, push y gitops), que no se lanza solo. Los archivos de workflow **no** están en el filtro de rutas: subir la CI no despliega nada. Para probar un cambio de CI, usa *Actions → el workflow → Run workflow* (solo funciona desde `main`, porque el rol de AWS solo confía en esa rama).

### Secrets y variables que debes crear

En GitHub, en el repositorio `store-app`: *Settings → Secrets and variables → Actions*.

| Nombre | Tipo | Valor | De dónde sale |
|---|---|---|---|
| `GITOPS_TOKEN` | **Secret** | Token de GitHub con permiso de escritura sobre `store-gitops` | Ver más abajo |
| `AWS_ROLE_ARN` | Variable | ARN del rol IAM de CI | Salida `github_actions_role_arn` de Terraform |
| `AWS_REGION` | Variable (opcional) | Región de ECR; por defecto `us-east-1` | La de `infra/terraform` |

**`GITOPS_TOKEN`:** crea un *fine-grained personal access token* en *GitHub → Settings → Developer settings → Personal access tokens*. Limítalo al repositorio `store-gitops` (*Only select repositories*), con el permiso *Repository permissions → Contents: Read and write* y una fecha de expiración. No necesita ningún otro permiso. Guárdalo como secret y no lo pegues en ningún archivo.

Con la CLI de GitHub (`gh`), sin escribir el token en el historial:

```bash
cd infra/terraform
gh variable set AWS_ROLE_ARN --repo "<USUARIO>/store-app" --body "$(terraform output -raw github_actions_role_arn)"
read -rs GITOPS_TOKEN        # pega el token y pulsa Enter (no se muestra)
gh secret set GITOPS_TOKEN --repo "<USUARIO>/store-app" --body "$GITOPS_TOKEN"
unset GITOPS_TOKEN
```

No hay llaves de acceso de AWS en GitHub: la CI entra por OIDC y el rol solo se puede asumir desde la rama `main` de `<USUARIO>/store-app`.

### Antes del primer push de un componente

Si haces push a `main` de un componente antes de tener esto listo, el workflow falla en el login de AWS o en el checkout de `store-gitops`. Comprueba en este orden:

1. Infraestructura aplicada (`infra/terraform/README.md`): repositorios ECR y rol de CI creados.
2. `AWS_ROLE_ARN` y `GITOPS_TOKEN` creados en GitHub.
3. `store-gitops` subido a GitHub y con la `root-app` aplicada (ver su `README.md`), junto con los Secrets de las bases de datos.
4. Hacer push de un cambio en un componente y seguir *Actions*: `test` → `build-and-push` → `update-gitops`.
5. Ver el commit `deploy(<servicio>): <sha>` en `store-gitops`, el cambio en Argo CD y la versión nueva en el pie de página de la aplicación.

Si `store-gitops` tiene protección de rama en `main`, el commit del bot será rechazado: permite que el dueño del token omita la protección (o permite pushes de ese usuario).

### Revisar los workflows sin ejecutarlos

Los workflows solo corren en GitHub. En local se pueden revisar con `actionlint` y probar la lógica de gitops contra un repositorio git temporal (no toca ningún remoto):

```bash
actionlint                                           # desde la raíz del repositorio
bash .github/scripts/test-update-gitops.sh "$(mktemp -d)" "$(command -v kustomize)" ../store-gitops
```

Las acciones de terceros están fijadas por versión mayor (`@v7`, `@v6`, …); se recomienda activar Dependabot para `github-actions` y revisar sus actualizaciones.

## Orden de los changes

1. `bootstrap-harness`
2. `products-service-fastapi`
3. `orders-service-go`
4. `frontend-angular` (incluye `docker-compose.yml`)
5. `infra-aws-terraform` (incluye `infra/terraform/argocd`)
6. `gitops-manifests` (repo `../store-gitops`)
7. `ci-github-actions`
8. `demo-visible-change`
