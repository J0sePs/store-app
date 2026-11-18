# Bitácora de progreso — store-app

> Cualquier agente (Claude Code, opencode) debe leer este archivo y `feature_list.json` al iniciar sesión.
> Al cerrar un change se agrega una sección nueva al final (la más reciente al final) y se actualiza `feature_list.json`.

## Estado actual

- **Change activo:** ninguno (todos los changes terminados; `demo-visible-change` archivado; pendiente de commit y push por el usuario)
- **Siguiente paso:** el usuario hace el commit y el `git push origin main` de `demo-visible-change` grabando el video (se lanzarán `frontend.yml` y `products-service.yml`); después, `docs/architecture.md` y `docs/presentation.md`, y apagar AWS al terminar.
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

## 2026-11-17 — Despliegue v1 en AWS (en curso)

> Sesión guiada: se pide confirmación antes de cada comando que crea recursos o cuesta dinero. Cuenta de AWS enmascarada (`************`); no se registran IP, contraseñas ni tokens.

### Paso 1 — Credenciales y permisos (solo lectura) ✅
- `aws sts get-caller-identity` → usuario IAM (credenciales locales), región `us-east-1`; pertenece al grupo `admin`.
- `aws iam simulate-principal-policy` → `allowed` para `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PutRolePolicy`, `iam:CreateOpenIDConnectProvider`, `iam:PassRole`, `eks:CreateCluster`, `ec2:CreateVpc`, `ec2:CreateNatGateway`, `ec2:AllocateAddress`, `ecr:CreateRepository`, `ecr:PutLifecyclePolicy` y `kms:CreateKey`.
- Estado previo de la cuenta: sin proveedor OIDC de GitHub (por eso `create_github_oidc_provider = true`), sin clústeres EKS, sin repositorios ECR, sin roles `store-eks-*`, 0 NAT gateways y 0 instancias EC2 en ejecución; 1 VPC de 5 y 1 EIP de 5 (cuotas sobradas).

### Paso 2 — `terraform.tfvars` (local, ignorado por git) ✅
- Creado desde el `.example` con `github_owner` y `github_repository` tomados del remoto de `store-app`, rama `main`, `create_github_oidc_provider = true` y `cluster_endpoint_public_access_cidrs` limitado a la IP pública del operador (/32).
- El creador del clúster queda administrador: `enable_cluster_creator_admin_permissions = true` y el plan incluye `aws_eks_access_entry` y `aws_eks_access_policy_association` (`AmazonEKSClusterAdminPolicy`) para su usuario IAM.

### Paso 3 — `terraform plan` (solo lectura) ✅, a la espera de confirmación para `apply`
- `terraform init` correcto; `terraform plan -out=plan.tfplan` → **Plan: 71 to add, 0 to change, 0 to destroy** (sin advertencias).
- Incidente corregido: el archivo del plan se llamó primero `tfplan`, que **no** estaba cubierto por el `.gitignore` (solo `*.tfplan`); se renombró a `plan.tfplan` y se comprobó con `git check-ignore`.
- Revisado en el plan: endpoint público con un único CIDR /32; rol de CI con sujeto exacto `repo:<owner>/store-app:ref:refs/heads/main`; 3 repos ECR (`scan_on_push`, `force_delete`, ciclo de vida `imageCountMoreThan`); nodos `t3.medium` × 2 (`AL2023_x86_64_STANDARD`); un solo NAT gateway.
- Costo estimado de la infraestructura (aprox., `us-east-1`): ≈ 0,24 USD/h sin balanceadores (EKS 0,10 + 2 nodos 0,083 + NAT 0,045 + IPv4 0,005 + volúmenes de nodos, KMS y logs de poca monta); ≈ 0,27 USD/h con el balanceador del frontend (≈ 6,5 USD/día).

### Paso 3b — El `apply` falló a mitad (plan Gratuito de AWS) ❌ → corregido con el change `infra-free-tier-nodes`
- El usuario confirmó el `apply` y se ejecutó `terraform apply plan.tfplan` (≈ 46 min en total). Se crearon el clúster EKS (11 min 42 s), la VPC, el NAT, los 3 repos ECR, los roles IAM, el proveedor OIDC de GitHub y el addon `vpc-cni`.
- **Falló el grupo de nodos:** `AsgInstanceLaunchFailures … InvalidParameterCombination – The specified instance type is not eligible for Free Tier`. La cuenta está en el **plan Gratuito** (`aws freetier get-account-plan-state` → `accountPlanType: FREE`, 129,60 USD de crédito) y solo permite instancias de la capa gratuita (`t3.micro`, `t3.small`, `t4g.*`, `t8i.*`, `c7i-flex.large`, `m7i-flex.large`); `t3.medium` no es elegible.
- Estado tras el fallo: clúster `ACTIVE` (Kubernetes 1.36), grupo de nodos `CREATE_FAILED`, sin nodos. Mientras no se corrija, el clúster cuesta ≈ 0,16 USD/h (EKS + NAT).
- Decisión del usuario (descartó las alternativas `c7i-flex`, `m7i-flex`, plan de pago y destruir todo): **2 × t3.small** y ajustar el sistema para que quepa (11 pods y ≈ 1,4 GiB por nodo), como change de OpenSpec.

### Paso 3c — Change `infra-free-tier-nodes`: código y plan listos ✅ (el `apply` lo ejecuta el usuario)
- Terraform: `node_instance_types = ["t3.small"]` (2/2/2), `coredns` con `replicaCount = 1` y `aws-ebs-csi-driver` con `controller.replicaCount = 1` (claves validadas con `aws eks describe-addon-configuration`), y Argo CD con `values.yaml` (`dex` y `notifications` apagados, ApplicationSet con 0 réplicas, 1 réplica y recursos pequeños en los 4 componentes).
- `store-gitops` (2 commits locales, **sin push**): 1 réplica por Deployment, `RollingUpdate` con `maxSurge: 1` y `maxUnavailable: 0`, requests de memoria PostgreSQL 128Mi, `products-service` 96Mi, `orders-service` 32Mi y frontend 32Mi, y PostgreSQL con `shared_buffers=32MB` y `max_connections=20`.
- **Presupuesto** (`scripts/check-capacity.py`): 17 pods de 22 (5 libres; 3 tras el rolling update de la demo) y 1 350 MiB de ≈ 2 868 (47 %).

  | Grupo | Pods | Memoria solicitada |
  |---|---|---|
  | DaemonSets (`aws-node`, `kube-proxy`, `ebs-csi-node` × 2) | 6 | ≈ 240 MiB |
  | kube-system (`coredns`, `ebs-csi-controller`) | 2 | ≈ 310 MiB |
  | Argo CD (controller, repo-server, server, redis) | 4 | 384 MiB |
  | Aplicación (frontend, 2 servicios, 2 bases) | 5 | 416 MiB |
  | **Total** | **17 de 22** | **≈ 1 350 MiB (47 %)** |

- Medición real (Docker): PostgreSQL pico de 79 MiB con 400 000 filas y 15 consultas simultáneas (límite 256 MiB, sin OOM); frontend 14 MiB, `products-service` 66 MiB y `orders-service` 6 MiB.
- **`terraform plan -out=plan.tfplan`: 4 to add, 0 to change, 1 to destroy.** Solo reemplaza el grupo de nodos fallido (`t3.medium` → `t3.small`) y crea `coredns`, `kube-proxy` y `aws-ebs-csi-driver`; 67 recursos sin cambios. Verificado con `terraform show -json`: **sin delete ni replace de clúster, VPC, NAT, subredes, IGW, EIP, KMS, OIDC ni ECR**.
- Costo estimado nuevo: ≈ 0,20 USD/h sin balanceadores y ≈ 0,23 con el del frontend (≈ 5,5 USD/día; ≈ 23 días con el crédito restante).
- Otros cambios: `openspec/config.yaml` (se corrigió también el error de YAML de `rules.specs` que arrastraba desde el principio), `AGENTS.md` (regla de capacidad), `infra/terraform/README.md` y README de `store-gitops`.
- Incidente menor corregido durante las pruebas: un `pkill -f` mío se mató a sí mismo; y la medición con `docker compose` ensució el stack local de la prueba anterior (se recreó limpio en el puerto 80).

### Siguiente paso (lo hace el humano)
- `cd infra/terraform && terraform apply plan.tfplan` (≈ 10–15 min; reemplaza el grupo de nodos y crea los 3 addons).
- Después se retoma el despliegue: paso 4 (`aws eks update-kubeconfig` y `kubectl get nodes`), paso 5 (etapa de Argo CD: plan, OK y apply), paso 6 (namespace y Secrets), paso 7 (secrets y variables de GitHub), paso 8 (primer build de los 3 componentes) y paso 9 (`root-app`).
- `git push` de `store-gitops` (2 commits locales) y de `store-app` solo con confirmación.

### Paso 3d — `terraform apply` del plan nuevo (nodos t3.small) ✅
- Confirmado por el usuario ("Tú lo ejecutas ahora") y ejecutado en segundo plano: `terraform apply plan.tfplan` → **Apply complete! 4 added, 0 changed, 1 destroyed** en 3 min 32 s (grupo de nodos nuevo 1 min 49 s; `kube-proxy` 29 s, `coredns` 53 s, `aws-ebs-csi-driver` 39 s; el grupo fallido se destruyó en 7 s). Cluster, VPC y NAT no se tocaron. Salidas: `cluster_name`, `ecr_repository_urls`, `github_actions_role_arn` y `update_kubeconfig_command`.

### Paso 4 — `kubectl` ✅
- `aws eks update-kubeconfig --name store-eks --region us-east-1` (el contexto actual de `kubectl` ya apunta al clúster nuevo, no al antiguo `app-nube-2-dev-eks`).
- `kubectl get nodes` → **2 nodos `Ready`** (`t3.small`, una por zona: `us-east-1a` y `us-east-1b`), Kubernetes v1.36.5.
- Capacidad real por nodo (`allocatable`): **11 pods, 1930m de CPU y 1 433 MiB** de memoria (la estimación era 1 434 MiB).
- Pods de `kube-system`: **8**, los esperados (6 DaemonSets: `aws-node`, `kube-proxy` y `ebs-csi-node` × 2; `coredns` y `ebs-csi-controller` con 1 réplica). Requests reales: 520m de CPU y 510 MiB de memoria (estimación inicial: 550 MiB, algo conservadora). Se corrigieron las constantes de `scripts/check-capacity.py`, el spec `cluster-capacity`, el design y el README: total **1 310 MiB = 46 %** de 2 866 MiB, 17 pods de 22 (5 libres; 3 tras el rolling update de la demo).

### Paso 5 — Etapa de Argo CD: `terraform plan` ✅, a la espera del OK para el `apply`
- `terraform init` y `terraform plan -out=plan.tfplan` en `infra/terraform/argocd` → **Plan: 3 to add, 0 to change, 0 to destroy** (el archivo del plan está ignorado por git).
- Recursos: `helm_release.argocd` (chart `argo-cd` 10.17.2, namespace `argocd`, `atomic`, `dex` y `notifications` apagados, ApplicationSet con 0 réplicas, 1 réplica y recursos mínimos en controlador, repo-server, server y redis), `kubernetes_annotations.gp2_not_default` (quita `is-default-class` a `gp2`) y `kubernetes_storage_class_v1.gp3` (`ebs.csi.aws.com`, `WaitForFirstConsumer`, expansión permitida, por defecto).
- Estado previo comprobado: solo existe la StorageClass `gp2`; no existen los namespaces `argocd` ni `store`. Esta etapa no añade costo propio (los pods van en los nodos existentes).

### Paso 5b — `terraform apply` de la etapa de Argo CD ✅
- Confirmado por el usuario ("ejecuta tú el apply de Argo CD") y ejecutado en segundo plano: **Apply complete! 3 added, 0 changed, 0 destroyed** en 1 min 9 s (`helm_release` 1 min 5 s).
- Verificado: pods de `argocd` **4 en `Running`** (`argocd-application-controller-0`, `argocd-redis`, `argocd-repo-server`, `argocd-server`) más el Job `argocd-redis-secret-init` en `Completed`; `argocd-applicationset-controller` en `0/0`; sin `dex` ni `notifications`. StorageClass **`gp3 (default)`** (`ebs.csi.aws.com`, `WaitForFirstConsumer`, expansión permitida) y `gp2` ya no es la predeterminada.
- Capacidad real tras instalar Argo CD: 13 pods en el clúster (22 admisibles); en `kubectl describe nodes` la suma de **limits** de memoria de un nodo llega al 127 % (sobreasignación de límites, normal) y los requests están en 27–34 %.

### Paso 6 — Change `infra-free-tier-nodes` validado y archivado ✅
- Validación: `openspec validate infra-free-tier-nodes` válido, `openspec validate --specs` 21 passed, `terraform fmt -check` y `validate` OK en ambas etapas, `scripts/check-capacity.py` OK (17 de 22 pods, 1 310 MiB = 46 %) y `./init.sh` con código 0. El clúster real cumple los escenarios de los specs: 2 × `t3.small`, `coredns` y `ebs-csi-controller` con 1 réplica, 4 pods de Argo CD y `gp3` por defecto.
- Archivado por confirmación del usuario en `openspec/changes/archive/2026-11-17-infra-free-tier-nodes/`. Specs sincronizados: `cluster-capacity` (nuevo, 3 requisitos) y modificados `eks-cluster`, `cluster-storage`, `argocd-install`, `k8s-workloads` y `k8s-databases`.
- Pendiente de commit (lo hace el humano): `store-app` con los cambios sin commitear; `store-gitops` con 2 commits locales (`4501d4e`, `ffcb37c`) sin push.

### Paso 7 — Namespace `store` y Secrets de las bases de datos ✅
- Confirmado por el usuario y creados con los comandos del README de `store-gitops`: `namespace/store`, `secret/products-db-credentials` y `secret/orders-db-credentials` (cada uno con `POSTGRES_PASSWORD` y `DATABASE_URL`).
- Contraseñas aleatorias de 32 caracteres (`openssl rand -hex 16`) generadas dentro de la misma orden: **no se mostraron ni se escribieron en ningún archivo**; las variables de shell se vaciaron al terminar. Comprobado sin ver valores: cada `DATABASE_URL` contiene su contraseña y apunta a `products-db` y `orders-db` respectivamente; `git` no ve archivos de secretos.
- No se aplicó el Application raíz de Argo CD (se hará después de ver las imágenes en ECR y los tags en `store-gitops`).

### Paso 8 — Secrets y variables de GitHub (lista entregada al usuario; los crea él) ⏳
- `store-app` → *Settings → Secrets and variables → Actions*: no existe ninguna variable ni secret todavía; Actions están habilitadas y no hay ejecuciones previas.
- A crear: **Secret `GITOPS_TOKEN`** (fine-grained PAT limitado a `store-gitops`, *Contents: Read and write*, con expiración), **Variable `AWS_ROLE_ARN`** (salida `github_actions_role_arn`; el valor con la cuenta no se registra aquí) y **Variable `AWS_REGION`** = `us-east-1` (opcional; es el valor por defecto). Las URL de ECR y la cuenta **no** hacen falta: el workflow las obtiene con `amazon-ecr-login`.
- `store-gitops` en GitHub: repositorio **público** (Argo CD lo lee sin credenciales), rama `main` **sin protección**, un solo commit remoto (`feat: add Kustomize manifests and Argo CD applications`).

### Paso 9 — `workflow_dispatch` para el primer build ✅ (sin cambios necesarios)
- Los 3 workflows (`frontend.yml`, `products-service.yml`, `orders-service.yml`) ya tienen `workflow_dispatch` y están en `origin/main` junto con `_deploy-component.yml`. `gh` 2.97 está instalado y autenticado. Se lanzan con `gh workflow run <archivo> --repo <dueño>/store-app --ref main` (solo desde `main`, por la confianza OIDC del rol).
- **Antes de lanzarlos, hacer push de los 2 commits locales de `store-gitops`**: así el bot de la CI edita sobre la versión con 1 réplica y los recursos nuevos, y se evita que el push posterior diverja.
- Orden previsto: GitHub (variables y token) → push de `store-gitops` → lanzar los 3 workflows → ver las 3 imágenes en ECR (`aws ecr describe-images`) y los commits `deploy(<servicio>): <sha>` en `store-gitops` → **solo entonces** aplicar `kubectl apply -f argocd/root-app.yaml`.

### Paso 10 — Primer build de los 3 componentes: ❌ fallan en el login OIDC (diagnóstico)
- Tras comprobar que existen `AWS_ROLE_ARN`, `AWS_REGION` y `GITOPS_TOKEN` y que ambos repos están sincronizados, se lanzaron con `gh workflow run <archivo> --ref main` los 3 workflows (runs `44225589495` frontend, `44225593951` products-service y `44225598166` orders-service; commit `0688166`).
- Resultado idéntico en los 3: el job `test` pasa; **`Build and push image` falla en el paso `Configure AWS credentials (OIDC)`** con `Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity` (12 reintentos); `update-gitops` queda `skipped` (el diseño funciona: no se tocó `store-gitops`). No se publicó ninguna imagen.
- **Causa raíz** (comprobada en solo lectura): GitHub tiene activado en el repositorio `use_immutable_subject: true` (`gh api repos/<dueño>/store-app/actions/oidc/customization/sub` → `sub_claim_prefix: repo:<dueño>@<id del dueño>/store-app@<id del repo>`). El claim `sub` del token lleva los **ids numéricos** (dueño `146149882`, repositorio `1461989222`, coinciden con `gh api repos/...`), y la política de confianza del rol exige el formato antiguo `repo:<dueño>/store-app:ref:refs/heads/main`, así que AWS rechaza el token.
- Descartado: la variable `AWS_ROLE_ARN` es idéntica a la salida de Terraform (misma longitud y contenido) y `AWS_REGION` es `us-east-1` sin espacios; el proveedor OIDC existe (`token.actions.githubusercontent.com`, audiencia `sts.amazonaws.com`) y las condiciones `aud` e `iss` de la política son correctas.
- Corrección propuesta: el `sub` de la política pasa al formato con ids (`repo:<dueño>@<id>/store-app@<id>:ref:refs/heads/main`), sin comodines; los ids no son secretos y se obtienen con `gh api repos/<dueño>/store-app --jq '.id, .owner.id'`.

### Paso 11 — Change `fix-oidc-immutable-subject`: código y plan listos ✅ (el `apply` espera el OK del usuario)
- Elegido por el usuario entre tres opciones (change de OpenSpec, arreglo directo o desactivar el sujeto inmutable en GitHub); se descartó desactivar el sujeto inmutable porque quita la protección contra *repo-jacking*.
- Terraform: variables `github_owner_id` y `github_repository_id` (`number`, por defecto `null`; las dos o ninguna, con validación en español), un `local` que calcula el sujeto exacto (con ids `repo:<dueño>@<id>/<repo>@<id>:ref:refs/heads/<rama>`; sin ellos, el formato antiguo) y la salida `github_actions_subject`. Los ids reales se tomaron de `gh api` y están solo en `terraform.tfvars` (ignorado por git); `terraform.tfvars.example` lleva marcadores. Los workflows no cambian.
- Pruebas sin tocar AWS: un solo id, solo el del repositorio y un id no positivo fallan con mensaje en español; el sujeto calculado con ids es exactamente el que emite GitHub y el del formato antiguo es el anterior; ninguno contiene comodines.
- **`terraform plan -out=plan.tfplan`: 0 to add, 1 to change, 0 to destroy.** Analizado con `terraform show -json`: único cambio = modificación **en el sitio** de `module.github_actions_role.aws_iam_role.this[0]`; sin reemplazo; `Action`, `Effect`, `Principal`, `aud` e `iss` idénticos; el `sub` pasa de `repo:<dueño>/store-app:ref:refs/heads/main` a `repo:<dueño>@<id>/store-app@<id>:ref:refs/heads/main`, valor único y sin comodines. Sin costo.
- Documentación: `infra/terraform/README.md` (variables, viñeta de seguridad, sección "Ids de GitHub para el rol de CI" y entrada de problemas frecuentes para `Not authorized to perform sts:AssumeRoleWithWebIdentity`) y la sección de CI del `README.md`.
- Verificaciones: `terraform fmt -check` y `validate` OK en las dos etapas, `openspec validate fix-oidc-immutable-subject` válido, `./init.sh` con código 0.

### Paso 12 — Corrección OIDC aplicada y primer build en verde ✅
- Con el OK del usuario se ejecutó `terraform apply plan.tfplan` → **0 added, 1 changed, 0 destroyed** (solo la política de confianza del rol de CI). Política real comprobada con `aws iam get-role`: `sub` = `repo:<dueño>@<id>/store-app@<id>:ref:refs/heads/main` (único valor, sin comodines), `aud` e `iss` intactos; la salida `github_actions_subject` coincide.
- Relanzados los 3 workflows (`gh workflow run <archivo> --ref main`; runs `44226929066`, `44226932332` y `44226936001`, commit `0688166`): **los tres terminan en `success`**, con sus 3 jobs (`test`, `Build and push image` —el paso OIDC ya pasa— y `Update store-gitops`). Los 3 intentos anteriores (`44225589495`, `44225593951`, `44225598166`) habían fallado en OIDC.

### Paso 13 — Verificación de imágenes y de `store-gitops` ✅
- **ECR** (`describe-images`): `frontend` (20,1 MiB), `products-service` (67,8 MiB) y `orders-service` (4,3 MiB), todas con el tag **`0688166`** = SHA corto del commit; **ninguna con `latest`**.
- **`store-gitops` en GitHub**: tres commits del bot `github-actions[bot]` encima de los del usuario: `deploy(products-service): 0688166`, `deploy(orders-service): 0688166` y `deploy(frontend): 0688166`; cada uno toca solo su `apps/<servicio>/kustomization.yaml` (bloque `images`).
- `git pull --rebase` en `../store-gitops` (rama alineada con `origin/main`). `kubectl kustomize` de los 3 componentes: imagen `...:0688166` y `APP_VERSION` = `0688166` (contrato de la CI verificado de punta a punta).
- **Escaneo de ECR** (`scan on push`, tipo BASIC): `orders-service` sin hallazgos; `products-service` 3 HIGH, 12 MEDIUM y 3 LOW; `frontend` 12 CRITICAL, 63 HIGH, 57 MEDIUM y 12 LOW. Causa del frontend: la imagen base `nginxinc/nginx-unprivileged:1.27-alpine` es antigua (OpenSSL 3.3.3-r0, curl 8.12.1-r1, libxml2 2.13.4-r6, expat…). No bloquea la demo; **mejora pendiente**: subir la imagen base del frontend (y revisar `python:3.12-slim`) en un change aparte.

### Paso 14 — Pre-vuelo del Application raíz (sin aplicar) ✅, a la espera del OK
- `kubectl apply --dry-run=server -f argocd/root-app.yaml` → `application.argoproj.io/store-root created (server dry run)` (solo un aviso benigno sobre el nombre del finalizador estándar de Argo CD). `repoURL` = `store-gitops` (público, Argo CD lo lee sin credenciales), ruta `argocd/apps` y 5 Applications.
- Estado previo: 12 pods en el clúster, Secrets `products-db-credentials` y `orders-db-credentials` presentes en `store`, y ninguna Application todavía. **El Application raíz NO se ha aplicado.**

### Paso 15 — Application raíz aplicada (bootstrap único) ✅
- Con el OK explícito del usuario se ejecutó `kubectl apply -f argocd/root-app.yaml` → `application.argoproj.io/store-root created`. Argo CD creó las 5 Applications (`frontend`, `products-service`, `orders-service`, `products-db`, `orders-db`) y sincronizó `store-gitops` (rama `main`).

### Paso 16 — Verificación del despliegue v1 ✅
- `kubectl get applications -n argocd`: **las 6 Applications (raíz y 5 componentes) en `Synced` / `Healthy`**.
- `kubectl get pods,svc -n store`: 5 pods en `Running` (`frontend`, `products-service`, `orders-service`, `products-db-0`, `orders-db-0`); los dos servicios muestran **2 reinicios** cada uno por arrancar antes de que sus bases estuvieran listas (esperado: reintentan la conexión y Kubernetes los reinicia; después estables). PVC `data-products-db-0` y `data-orders-db-0` en `Bound`, 5Gi, `gp3`.
- Versión desplegada = tag: los 3 Deployments usan `...:0688166` y `APP_VERSION=0688166`.
- **URL del frontend**: `kubectl get svc frontend -n store -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'` (balanceador clásico de AWS; el DNS respondió a los ~5 s). A través de él: `/health` → `{"status":"ok","version":"0688166"}`, `/version.json` → `0688166`, `/api/products/health` y `/api/orders/health` → `0688166` (200), `/api/products` → 3 productos de ejemplo, `/api/orders` → `[]`, y `/` y `/orders` → 200 (SPA). No se creó ningún dato de prueba.
- La captura con Chromium headless del balanceador falló con `ERR_BLOCKED_BY_CLIENT` (restricción del entorno del navegador; `curl` sí llega): la UI visual la revisa el usuario en su navegador.
- **UI de Argo CD** (comprobada: `port-forward` y respuesta HTTP 200, Argo CD v3.6.1; el Secret `argocd-initial-admin-secret` existe): `kubectl port-forward svc/argocd-server -n argocd 8080:443` y abrir `https://localhost:8080` (certificado autofirmado), usuario `admin`; contraseña inicial: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo`. La contraseña no se mostró ni se registró.
- Costo actual: ≈ 0,23 USD/h (infra ≈ 0,20 + balanceador ≈ 0,03). Recordatorio: al terminar, seguir la sección de `destroy` de `infra/terraform/README.md` (borrar primero las Applications, los PVC y el balanceador).

### Paso 17 — Verificación del usuario y archivado de `fix-oidc-immutable-subject` ✅
- El usuario confirmó la v1 en el navegador y en la UI de Argo CD.
- Archivado `fix-oidc-immutable-subject` en `openspec/changes/archive/2026-11-17-fix-oidc-immutable-subject/`; spec `github-oidc-access` actualizado (requisito del rol de CI con el sujeto inmutable; 3 requisitos y 14 escenarios); `openspec validate --specs` → 21 passed.
- Comprobado que el commit pendiente **no toca** `frontend/`, `products-service/` ni `orders-service/`, así que al hacer push **no se dispara ningún workflow** de componente (los filtros `paths` son `<componente>/**`). El commit y el push los hace el usuario.

### Paso 18 — Commit de `fix-oidc-immutable-subject` publicado ✅ (mensaje corregido)
- El usuario hizo el commit y el push desde su terminal, pero el commit `0215de6` se publicó con el texto literal del marcador (`<mensaje que te proponga>`) como mensaje. Con la confirmación del usuario (AGENTS.md exige confirmar cualquier `force push`) se reescribió **solo ese último commit**: `git commit --amend` con el mensaje propuesto y `git push --force-with-lease=main:<hash anterior> origin main` → `0215de6` pasó a `f2a8ecb`, con **el mismo árbol** (los 14 archivos no cambiaron). `origin/main` y la copia local coinciden.
- Los 14 archivos están fuera de `frontend/`, `products-service/` y `orders-service/`: la reescritura no disparó ningún workflow.
- Lección: al pegar comandos con `<...>`, sustituir el marcador por el texto antes de ejecutarlos.

### Paso 19 — Change `demo-visible-change` (v2 de la demo) implementado y archivado ✅ — SIN push
- **products-service:** campo `category` (`VARCHAR(100) NOT NULL DEFAULT 'General'`) en el modelo y la API (opcional en `POST`, de 1 a 100 caracteres, vacía o de solo espacios → 422; en la siembra de instalaciones nuevas: `Periféricos`, `Periféricos` y `Monitores`). **Migración idempotente al arrancar** (`app/db/migrations.py`): en PostgreSQL `ALTER TABLE products ADD COLUMN IF NOT EXISTS category VARCHAR(100) NOT NULL DEFAULT 'General'` (segura con dos pods a la vez y solo de metadatos); en SQLite (tests) se comprueba la columna con el inspector. Tests: 37 passed (API y migración sobre una tabla con el DDL de la v1).
- **frontend:** banner "Versión 2 - desplegada con GitOps" (componente `release-banner`, `role="status"`) en el `.banner-slot` del shell, columna "Categoría" (muestra `—` si el servicio no la envía, para tolerar el orden de despliegue) y campo opcional en el formulario. Tests: 45 passed; lint y build OK.
- **Prueba contra PostgreSQL real** (`scripts/test-products-migration.sh`, 16 comprobaciones; probado con dos commits anteriores): la **v1 exacta de AWS (commit `0688166`)** crea la tabla sin `category` con 5 filas → la **v2** añade la columna, los 5 productos pasan a `General` y la huella de los datos no cambia → al reiniciar la v2, `la columna ya existe` y sin cambios → la **v1 arranca de nuevo sobre la base migrada**, lee y crea productos sin errores (su producto recibe `General`). Confirmado también con el stack local, que ya tenía la tabla de la v1 y migró con sus datos.
- Captura real con Chromium headless: banner azul en `/products` y `/orders`, encabezados `ID, Nombre, Categoría, Precio, Stock, Creado`, `General` en los existentes y `Muebles` en uno nuevo con categoría.
- Capacidad sin cambios (`scripts/check-capacity.py`: 17 de 22 pods, 46 % de memoria). Stack local recreado limpio en el puerto 80 con el código v2.
- Specs sincronizados y change archivado en `openspec/changes/archive/2026-11-18-demo-visible-change/`: `products-catalog` (3 requisitos modificados: listar, crear y persistencia/arranque) y `store-frontend` (vista de productos modificada y requisito nuevo "Banner de versión").
- **El push dispara 2 workflows** (`frontend.yml` y `products-service.yml`; no `orders-service.yml`) por los 12 archivos de `frontend/` y 8 de `products-service/`; sus `update-gitops` se serializan. Orden esperado de la demo: push → workflows → ECR (2 tags nuevos) → 2 commits `deploy(...)` en `store-gitops` → Argo CD `Synced` → rolling update (el pod nuevo de `products-service` migra la base de AWS mientras el viejo sigue sirviendo) → navegador con banner, columna "Categoría" y versiones nuevas en el pie.

