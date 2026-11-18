# Bitácora de progreso — store-app

> Cualquier agente (Claude Code, opencode) debe leer este archivo y `feature_list.json` al iniciar sesión.
> Al cerrar un change se agrega una sección nueva al final (la más reciente al final) y se actualiza `feature_list.json`.

## Estado actual

- **Change activo:** ninguno (`ci-github-actions` terminado, archivado y con commit)
- **Siguiente paso:** proponer `demo-visible-change` (`change-7`) con `/openspec-propose demo-visible-change` y el prompt de `docs/prompts.md`, cuando el humano lo pida. `git push` pendiente de confirmación.
- **Verificación del entorno:** `./init.sh`

## Plantilla por change

```
## YYYY-MM-DD — <nombre-del-change>

### Qué se hizo
- ...

### Evidencia
- `comando` → resultado

### Siguiente paso
- ...
```

## Historial

<!-- Las secciones de cada change cerrado se agregan debajo de esta línea. -->

## 2026-11-17 — bootstrap-harness

### Qué se hizo
- Se creó `feature_list.json` con los 8 changes del orden aprobado (`change-0` a `change-7`).
- Se creó esta bitácora (`progress.md`) y `init.sh` (herramientas, versiones, tests de componentes existentes, validación de `feature_list.json`).
- Se agregó la regla de sesión en `AGENTS.md` (sección 4, punto 7), se listaron los archivos nuevos en la estructura y se corrigió el nombre de la skill a `harness-creator`.
- Se creó `README.md` en la raíz con el flujo de trabajo.
- Se instaló Go 1.27.4 en `~/.local/go`, se renombraron `.gitignore` y `docs/prompts.md` y se actualizaron los comandos de OpenSpec a `/openspec-*` en `CLAUDE.md` y `docs/prompts.md`.
- Se sincronizó el spec a `openspec/specs/project-harness/spec.md` y se archivó el change en `openspec/changes/archive/2026-11-17-bootstrap-harness/`.

### Evidencia
- `python3 -c "..."` sobre `feature_list.json` → 8 entradas, 1 `in_progress`, todos los campos presentes.
- `bash -n init.sh` → sin errores; `./init.sh` → código 0, `go` reportado como faltante, 3 componentes omitidos por no existir.
- Copia temporal con varios `in_progress` → aviso; `done` sin `evidence` → código 1.
- `openspec validate bootstrap-harness` → válido (1 advertencia: requisito largo).
- `./init.sh` con Go en el `PATH` → código 0, "Todas las herramientas están instaladas"; 15/15 tareas marcadas.
- `openspec validate --specs` → 1 passed, 0 failed; `openspec list` → sin changes activos.

### Siguiente paso
- ~~Instalar `go`~~: hecho. Go 1.27.4 en `~/.local/go` (tarball oficial con sha256 verificado). Con `PATH="$HOME/.local/go/bin:$PATH" ./init.sh` → "Todas las herramientas están instaladas". Falta agregarlo al `PATH` de forma permanente en `~/.zshrc` (lo hace el usuario).
- ~~Renombrar `gitignore` y `prompts(1).md`~~: hecho (`.gitignore` y `docs/prompts.md`).
- Pendiente del usuario: `PATH` permanente de Go en `~/.zshrc` y el commit de este change.
- Proponer `products-service-fastapi` con el prompt de `docs/prompts.md` (tras confirmar el commit).

## 2026-11-17 — products-service-fastapi

### Qué se hizo
- Se creó `products-service/` con FastAPI, SQLAlchemy 2 y `psycopg`: `GET /products`, `GET /products/{id}`, `POST /products` y `GET /health` (versión desde `APP_VERSION`, por defecto `dev`).
- Modelo `Product` (`id`, `name`, `price` Numeric(10,2), `stock`, `created_at`); la tabla se crea al arrancar y se siembran 3 productos solo si está vacía; reintento de conexión (3 intentos, 2 s).
- Tests con pytest sobre SQLite en memoria (23), `Dockerfile` multi-stage con usuario no root (uid 10001) y `README.md` en español.
- `init.sh` ahora usa el venv de `products-service` para correr pytest.
- Specs sincronizados a `openspec/specs/` (`products-catalog`, `service-health`) y change archivado en `openspec/changes/archive/2026-11-17-products-service-fastapi/`.

### Evidencia
- `pytest` → 23 passed; `ruff check .` y `ruff format --check .` → sin errores.
- `docker build -t products-service:dev products-service/` → OK; `docker run --entrypoint id products-service:dev -u` → `10001`.
- Contra `postgres:16-alpine` (contenedores y red temporales, ya eliminados): `/health` 200 con `APP_VERSION=0.1.0`; `GET /products` devuelve 3; `POST` → 201; `/products/9999` → 404 `Producto no encontrado`; precio 0 → 422; tras reiniciar el servicio quedan 4 filas (3 + 1), sin duplicar la siembra.
- `openspec validate products-service-fastapi` → válido; `./init.sh` → código 0.

### Decisiones y notas
- `create_app(engine=None)` y `app = create_app()` sin tocar la base al importar; la falta de `DATABASE_URL` falla en el arranque (lifespan) con mensaje en español.
- Los mensajes 422 de Pydantic siguen en inglés (fuera de alcance).
- El `venv` vive en `products-service/.venv/` (ignorado por git).

### Siguiente paso
- Proponer `orders-service-go` (necesita Go en el `PATH`: ya agregado a `~/.zshrc`).
- `git push` pendiente de confirmación del humano.

## 2026-11-17 — orders-service-go

### Qué se hizo
- Se creó `orders-service/` en Go con chi v5 y pgx v5: `GET /orders`, `GET /orders/{id}`, `POST /orders` y `GET /health` (versión desde `APP_VERSION`, por defecto `dev`), puerto 8080.
- Modelo `Order` (`id`, `product_id` como simple referencia, `quantity`, `customer`, `status`, `created_at`); `status` lo fija el servicio en `pending`. Migración SQL embebida e idempotente al arrancar, con reintento de conexión (5 intentos, 2 s) y apagado ordenado.
- Layout `cmd/server` + `internal/{config,handler,model,repository}`; el handler depende de la interfaz `OrderStore`, así que los tests usan un fake con `httptest`.
- `Dockerfile` multi-stage con imagen final distroless (usuario 65532, sin shell) y `README.md` en español.

### Evidencia
- `go test ./...` → ok en `config`, `model` y `handler`; `gofmt -l .` y `go vet ./...` sin hallazgos.
- `docker build -t orders-service:dev orders-service/` → OK (12,6 MB); usuario `65532:65532`; `docker run --entrypoint sh` falla (no hay shell).
- Contra `postgres:16-alpine` (contenedores y red temporales, ya eliminados) con un contenedor `curl` en la misma red: `/health` 200; `GET /orders` → `[]`; `POST` → 201 con `status` `pending` aunque el cliente mandó `shipped`; `/orders/9999` → 404; `/orders/abc` → 400; `quantity` 0 → 400; tras reiniciar el pedido sigue ahí; el servicio se apaga con mensaje en español.
- Sin `DATABASE_URL` el binario sale con código 1 y `falta la variable de entorno DATABASE_URL`.
- `openspec validate orders-service-go` → válido; `./init.sh` → código 0 (ejecuta pytest y go test).
- Spec sincronizado a `openspec/specs/orders-management/` y change archivado en `openspec/changes/archive/2026-11-17-orders-service-go/`.

### Decisiones y notas
- `go.mod` quedó en `go 1.25` (no 1.24 como en el diseño original): `pgx/v5` y `x/sync`/`x/text` lo exigen. Se actualizaron design y tasks y la imagen de build es `golang:1.25-alpine`.
- Formato de error `{"error": "..."}` en este servicio frente a `{"detail": "..."}` en `products-service`: el frontend debe leer ambos.
- El repositorio pgx no tiene tests automáticos; se validó contra PostgreSQL real con Docker.
- Se borró un binario `orders-service/server` suelto que dejó un `go build ./cmd/server`; usar `-o bin/server`.

### Siguiente paso
- `git push` pendiente de confirmación del humano.
- Proponer `frontend-angular` (necesita `node`/`npm`; Angular CLI se instalará como dependencia del proyecto).

## 2026-11-17 — frontend-angular

### Qué se hizo
- Se creó `frontend/` con Angular 22 (standalone, Vitest + jsdom, `angular-eslint`): `products-page` (tabla y alta), `orders-page` (tabla y alta con selector de producto; el nombre se resuelve en el frontend), `version-footer` (Frontend, Productos y Pedidos con `no disponible`, consulta cada 30 s) y `app-shell`. Texto visible en español, componentes en inglés.
- `core/`: modelos tipados, servicios HTTP con rutas relativas (`/api/products`, `/api/orders`, `/health` de cada uno), `VersionService` y `toUserMessage`, que normaliza `{"detail": ...}` (products) y `{"error": ...}` (orders).
- `nginx.conf` (+ `proxy_params.inc`): SPA con fallback, proxy que quita `/api`, `location =` para los `/health`, `/api/...` desconocido → 404, `version.json` sin caché. `Dockerfile` multi-stage con `nginx-unprivileged` (usuario 101, puerto 8080) y `ARG APP_VERSION` validado.
- `docker-compose.yml` (frontend, products-service, products-db, orders-service, orders-db) y `.env.example`; las contraseñas vienen de `.env` (ignorado por git) y compose falla en español si faltan.
- `README.md` del frontend y de la raíz con la sección "Ejecutar todo en local".

### Evidencia
- `npm test -- --watch=false` → 37 passed; `npm run lint` y `npm run build` sin errores.
- `nginx -t` con la imagen oficial → correcto. `docker build --build-arg APP_VERSION=abc1234` → `/version.json` = `{"version":"abc1234"}` con `Cache-Control: no-store`; sin argumento → `dev`; `APP_VERSION='a"b'` → build falla con mensaje en español; usuario 101.
- `docker compose up --build -d`: `/` y `/orders` 200; `GET/POST /api/products` y `/api/orders` por el proxy (201, 404, 400 correctos); `/api/products/health` y `/api/orders/health` 200; tras `docker compose restart` quedan 1 pedido y 4 productos.
- Con `PRODUCTS_APP_VERSION=2.0.0`: `/api/products/health` → `2.0.0` y el pie de página real (Chromium headless) muestra `Productos: 2.0.0`. Capturas de `/products` y `/orders` revisadas.
- `docker compose config` sin `.env` falla con `Falta PRODUCTS_DB_PASSWORD: copia .env.example a .env`; `git check-ignore .env` → ignorado y `.env.example` no.
- `openspec validate frontend-angular` → válido; `./init.sh` → código 0 (pytest, go test y tests del frontend).
- Contenedores, volúmenes y el `.env` de prueba se eliminaron (`docker compose down -v`).
- Specs sincronizados a `openspec/specs/` (`store-frontend`, `frontend-proxy`, `local-stack`) y change archivado en `openspec/changes/archive/2026-11-17-frontend-angular/`.

### Decisiones y notas
- Primer arranque local: `cp .env.example .env` y `docker compose up --build` (no hay contraseñas por defecto en git).
- Para el change de CI: los Dockerfile de `products-service` y `orders-service` aún no reciben `ARG APP_VERSION`; sin eso el pie mostrará `dev` para los servicios en Kubernetes. El frontend sí lo recibe como `--build-arg`.
- Para `gitops-manifests`: nginx resuelve `products-service` y `orders-service` al arrancar, así que los Services de Kubernetes deben llamarse exactamente así; el contenedor del frontend escucha en el 8080.
- Un `: ` sin comillas dentro de un valor YAML rompe el archivo (pasó en `docker-compose.yml`; sigue pendiente `openspec/config.yaml`, `rules.specs[1]`).
- La tabla de productos usa `<th>` por columna y el shell tiene `.banner-slot` para el change `demo-visible-change`.

### Siguiente paso
- `git push` pendiente de confirmación del humano.
- Proponer `infra-aws-terraform` (necesita `terraform`, `aws`, `kubectl`: ya instalados; `terraform apply` siempre con confirmación).

## 2026-11-17 — infra-aws-terraform

### Qué se hizo
- Se creó `infra/terraform/` (región `us-east-1`) con módulos oficiales `terraform-aws-modules`: VPC 6.8.0 (2 AZ, un NAT, etiquetas de balanceador), EKS 21.30.2 (Kubernetes 1.36, 2 × t3.medium AL2023 en subredes privadas, administrador para quien crea el clúster, endpoint público limitado por variable), ECR 3.2.1 (3 repos con escaneo al subir, `force_delete` y ciclo de vida de 10 imágenes, etiquetas mutables), e IAM 6.11.1 (rol IRSA del driver EBS CSI, proveedor OIDC de GitHub opcional y rol de CI).
- El rol de CI solo se asume desde `repo:<github_owner>/<github_repository>:ref:refs/heads/<github_branch>` (igualdad exacta) y solo puede subir/consultar imágenes de los 3 ECR (más `ecr:GetAuthorizationToken`); sin permisos sobre EKS ni IAM.
- El addon EBS CSI es un `aws_eks_addon` aparte del módulo EKS para evitar una dependencia circular con el OIDC del clúster (design y tasks actualizados antes de codificar).
- Etapa `infra/terraform/argocd/` con estado propio: `helm_release` de `argo-cd` (chart 10.17.2, Service `ClusterIP`), StorageClass `gp3` por defecto (`ebs.csi.aws.com`, `WaitForFirstConsumer`) y `gp2` sin marca de predeterminada. Autenticación de `helm` y `kubernetes` con `aws eks get-token`.
- `variables.tf`, `outputs.tf` (`cluster_name`, `region`, `ecr_repository_urls`, `github_actions_role_arn`, `update_kubeconfig_command`), `terraform.tfvars.example` en ambas etapas, `.terraform.lock.hcl` versionados y `infra/terraform/README.md` en español (pasos de apply y destroy, costo ≈ 0,24 USD/h sin balanceadores y ≈ 0,27 USD/h con el del frontend, advertencia de borrar Services `LoadBalancer` y PVC antes del destroy).

### Evidencia
- **No se ejecutó `terraform plan`, `apply` ni `destroy`; no se creó ni modificó ningún recurso en AWS.** Solo `terraform init -backend=false`, `fmt` y `validate`.
- `terraform validate` → válido en `infra/terraform` y en `infra/terraform/argocd`; `terraform fmt -check -recursive` sin cambios pendientes.
- Búsqueda de `AKIA`, `aws_secret_access_key` y `password =` en `infra/` → sin coincidencias; `git check-ignore` confirma que `terraform.tfvars`, `*.tfstate*`, `*.tfplan` y `.terraform/` quedan ignorados y `.terraform.lock.hcl` y `terraform.tfvars.example` no.
- Sujeto OIDC exacto, sin comodines, sin `eks:*` ni `iam:*`; outputs sin secretos; ninguna carpeta contiene manifiestos de la aplicación.
- `openspec validate infra-aws-terraform` → válido; `./init.sh` → código 0.
- Specs sincronizados a `openspec/specs/` (`eks-cluster`, `container-registry`, `cluster-storage`, `github-oidc-access`, `argocd-install`, `infra-conventions`) y change archivado en `openspec/changes/archive/2026-11-17-infra-aws-terraform/`.

### Decisiones y notas para los siguientes changes
- **Antes del apply (lo hace el humano):** `cp terraform.tfvars.example terraform.tfvars` y poner `github_owner`; revisar con `terraform plan`. Si la cuenta ya tiene el proveedor OIDC de GitHub, `create_github_oidc_provider = false`.
- **`gitops-manifests`:** la StorageClass se llama `gp3` (PVC con `storageClassName: gp3`); los Services deben llamarse `products-service` y `orders-service` (nginx los resuelve al arrancar); el frontend escucha en el 8080 y se expone con un Service `LoadBalancer`; las imágenes viven en `<cuenta>.dkr.ecr.us-east-1.amazonaws.com/{frontend,products-service,orders-service}`.
- **`ci-github-actions`:** usa el rol `github_actions_role_arn` por OIDC (permiso `id-token: write`); ECR acepta etiquetas mutables pero `latest` sigue prohibida; falta `ARG APP_VERSION` en los Dockerfile de los servicios.
- **Capacidad:** 2 × t3.medium admiten ~34 pods en total (kube-system + EBS CSI + Argo CD + la aplicación): poco margen.
- El estado de Terraform es local; no borrar `terraform.tfstate`.

### Siguiente paso
- `git push` pendiente de confirmación del humano.
- Proponer `gitops-manifests` (repo `../store-gitops`, que ya tiene acceso de escritura).

## 2026-11-17 — gitops-manifests

### Qué se hizo
- En `../store-gitops` (repo aparte, sin commits todavía): `apps/{frontend,products-service,orders-service,products-db,orders-db}` con su `kustomization.yaml`, `argocd/root-app.yaml` (app-of-apps) y `argocd/apps/*.yaml` (una Application por componente: `automated`, `prune`, `selfHeal`, `CreateNamespace=true`, finalizador, namespace `store`), `.gitignore` y `README.md` en español.
- Deployments con probes en `/health`, requests/limits, `RollingUpdate` sin corte (`maxUnavailable: 0`), `securityContext` sin root; frontend 2 réplicas y servicios 1 (evita el choque de migración/siembra al primer arranque). Services: frontend `LoadBalancer` (80 → 8080), `products-service:8000` y `orders-service:8080` `ClusterIP`.
- `APP_VERSION` = tag de la imagen: bloque `replacements` de Kustomize que copia el tag del campo `image` (ya transformado por `images`). Imágenes por nombre lógico con `newName` de marcador (`000000000000.dkr.ecr.us-east-1.amazonaws.com/<nombre>`) y `newTag: "0000000"`.
- Bases de datos: StatefulSet `postgres:16-alpine` (uid 70, `PGDATA` en subdirectorio, `pg_isready`), PVC `gp3` de 5Gi y Service headless. Credenciales fuera de git: Secrets `products-db-credentials` y `orders-db-credentials` (`POSTGRES_PASSWORD` y `DATABASE_URL`) que se crean con `kubectl create secret` (comandos en el README).
- En `store-app`: el frontend ahora expone `GET /health` (`{"status":"ok","version":"<APP_VERSION>"}`, sin depender de los servicios) mediante `health.json` generado en el Dockerfile y `location = /health` en nginx; documentado en `frontend/README.md`.

### Evidencia
- **No se ejecutó `kubectl apply` ni nada contra ningún clúster.**
- `kubectl kustomize` correcto en los 5 componentes; 79 comprobaciones estáticas OK (probes, recursos, runAsNonRoot, `gp3`, headless, tipos de Service, Secrets, aislamiento entre bases, `APP_VERSION` == tag); 36 comprobaciones OK sobre las Applications (campos, `repoURL` igual al remoto de `store-gitops`).
- Contrato con la CI con el CLI real (`kustomize` v5.8.1, copia temporal): `kustomize edit set image` solo toca `images`, `APP_VERSION` sigue al tag y los tags que parecen números (`1234567`, `1234e56`) se entrecomillan solos. Efecto colateral: `kustomize edit` reformatea el archivo y elimina sus comentarios (documentado en el README).
- PostgreSQL arranca en Docker con las mismas restricciones del StatefulSet (uid 70, `--cap-drop ALL`, `no-new-privileges`, `PGDATA` en subdirectorio).
- Frontend: `docker build` con `APP_VERSION=abc1234` → `/health` `{"status":"ok","version":"abc1234"}` con `no-store`; sin argumento → `dev`; responde 200 con los upstream caídos (mientras `/api/products` da 502). `npm test` 37 passed; `docker compose config` correcto.
- Sin `kind: Secret`, `latest`, `AKIA`/`ghp_` ni contraseñas en `store-gitops`; los comandos del README pasan `bash -n` y no llevan valores literales.
- `openspec validate gitops-manifests` → válido; `./init.sh` → código 0.
- Specs sincronizados a `openspec/specs/` (`k8s-workloads`, `k8s-databases`, `argocd-applications`, `gitops-operations` y el requisito de health en `frontend-proxy`) y change archivado en `openspec/changes/archive/2026-11-17-gitops-manifests/`.

### Decisiones y notas para los siguientes changes
- **Orden de despliegue (lo hace el humano):** `kubectl create namespace store` y los dos Secrets → push de `store-gitops` a GitHub (`main`) → `kubectl apply -f argocd/root-app.yaml`. Hasta que la CI publique la primera imagen los pods de aplicación quedan en `ImagePullBackOff`; es lo esperado.
- **`ci-github-actions`:** en `apps/<nombre>` ejecutar `kustomize edit set image "$NAME=$ECR_REGISTRY/$NAME:$SHORT_SHA"` (nunca `sed`, nunca `kubectl apply`, nunca `latest`) y hacer commit en `store-gitops` con el token `GITOPS_TOKEN`. Añadir `ARG APP_VERSION` al build del frontend (ya lo soporta) y a los Dockerfile de los servicios (pendiente: hoy los servicios leen `APP_VERSION` del entorno que pone el Deployment, así que en Kubernetes ya muestran el tag correcto sin tocar la imagen).
- `repoURL` de las Applications: `https://github.com/J0sePs/store-gitops.git` (remoto actual); si cambia, el README indica el `sed` de 6 archivos.
- El contexto actual de `kubectl` apunta a un clúster antiguo que ya no existe (`app-nube-2-dev-eks`): tras el `apply` de Terraform ejecutar `aws eks update-kubeconfig --name store-eks --region us-east-1` antes de cualquier `kubectl`.
- Frontend como `LoadBalancer` clásico (sin anotaciones); cada base solo puede reprogramarse en nodos de la zona de su volumen EBS.

### Siguiente paso
- `git push` de `store-app` y de `store-gitops` pendiente de confirmación del humano (`store-gitops` tiene su primer commit).
- Proponer `ci-github-actions`.

## 2026-11-17 — ci-github-actions

### Qué se hizo
- Workflows en `.github/workflows/`: `frontend.yml`, `products-service.yml` y `orders-service.yml` (push a `main` con `paths` de su carpeta y `workflow_dispatch`; job `test` con los comandos de `AGENTS.md`; job `deploy` que llama al reutilizable) y `_deploy-component.yml` (job `build-and-push`: OIDC con `aws-actions/configure-aws-credentials`, login a ECR, buildx, push con tag = SHA corto de 7 caracteres, `provenance: false`, comprobación con `aws ecr describe-images`; job `update-gitops` con `needs`, checkout de `<dueño>/store-gitops` con `GITOPS_TOKEN`, Kustomize 5.8.3 verificado con sha256 y llamada al script).
- `.github/scripts/update-gitops.sh`: `kustomize edit set image`, comprobación de que `APP_VERSION` y la imagen quedan con el SHA, commit `deploy(<servicio>): <sha>` como `github-actions[bot]` y push con `pull --rebase`, 5 intentos con espera creciente y reinicio desde el remoto si el rebase choca; sin cambios = salida correcta. `.github/scripts/test-update-gitops.sh` lo prueba en local (35 comprobaciones) contra un remoto git temporal.
- `README.md` raíz: sección "CI/CD con GitHub Actions" con el flujo, los secrets y variables (`GITOPS_TOKEN`, `AWS_ROLE_ARN`, `AWS_REGION`), cómo crear el token y la lista de comprobación del primer despliegue.

### Evidencia
- **Los workflows no se ejecutaron** (solo corren en GitHub tras el push) y no se creó ningún secret ni se tocó AWS ni ningún remoto: la prueba del script usó un repositorio git temporal y `store-gitops` real sigue con su único commit.
- `actionlint` v1.7.12 sin errores; `shellcheck` sin hallazgos; 84 comprobaciones estáticas OK (permisos, `GITOPS_TOKEN` solo en `update-gitops`, sin `${{ }}` dentro de `run`, versiones mayores en cada `uses:`, sin `latest`, `kubectl` ni llaves de AWS, nombres de jobs y steps en inglés).
- Prueba local del script: caso feliz, remoto adelantado (historia lineal), conflicto en el mismo `kustomization.yaml` (se reinicia desde el remoto y se conserva el commit ajeno), sin cambios, `APP_VERSION` incorrecta (falla antes del commit), push rechazado una vez, reintentos agotados (mensaje en español) y entradas inválidas (inyección rechazada). Dos mejoras salieron de la prueba: el script detecta "el remoto ya contiene este cambio" tras el rebase, y la prueba acepta los tags numéricos que Kustomize entrecomilla.
- `openspec validate ci-github-actions` → válido; `./init.sh` → código 0.
- Specs sincronizados a `openspec/specs/` (`ci-pipeline`, `ci-gitops-update`, `ci-secrets-and-docs`) y change archivado en `openspec/changes/archive/2026-11-17-ci-github-actions/`.

### Decisiones y notas
- **`APP_VERSION` no se edita:** Kustomize la copia del tag (change `gitops-manifests`); la CI solo verifica que coincide con el SHA.
- Los archivos de workflow no están en `paths`: subir la CI no dispara despliegues antes de que exista la infraestructura. Para probar un cambio de CI: *Run workflow* (solo desde `main`: el rol OIDC solo confía en esa rama).
- Acciones fijadas por versión mayor (`checkout`, `setup-*` y `build-push-action` v7, `configure-aws-credentials` v6, `amazon-ecr-login` v2, `setup-buildx` v4); no por SHA de commit.
- **Para `demo-visible-change`:** el cambio toca frontend y products-service, así que correrán dos workflows en paralelo y sus `update-gitops` se serializan. `products-service` crea la tabla con `create_all`, que **no** añade columnas a una tabla existente: la columna `category` necesita una migración al arrancar (por ejemplo `ALTER TABLE products ADD COLUMN IF NOT EXISTS category ...`), si no, en un clúster con datos el servicio fallaría. Las tablas `<th>` del frontend ya están listas para la columna "Categoría" y el shell tiene `.banner-slot`.
- **Orden real para el primer despliegue (lo hace el humano):** `terraform apply` (infra) → `aws eks update-kubeconfig` → `terraform apply` de `argocd/` → namespace `store` y Secrets de las bases → `kubectl apply -f argocd/root-app.yaml` (con `store-gitops` ya subido a GitHub) → crear `AWS_ROLE_ARN` y `GITOPS_TOKEN` en GitHub → push de un cambio en un componente.

### Siguiente paso
- `git push` pendiente de confirmación del humano.
- Proponer `demo-visible-change`.

