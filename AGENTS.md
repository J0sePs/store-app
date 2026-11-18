# AGENTS.md — store-app

Instrucciones para agentes de IA (Claude Code, opencode u otros) que trabajen en este repositorio.

## 1. Qué es este proyecto

Proyecto académico: sistema de **microservicios** desplegado en **AWS EKS** con **GitOps**.

- `frontend/` — Angular (standalone components) servido con nginx. nginx hace de proxy inverso:
  `/api/products/` → `products-service:8000` y `/api/orders/` → `orders-service:8080`.
- `products-service/` — Python + FastAPI + SQLAlchemy, con su propia PostgreSQL (`products-db`).
- `orders-service/` — Go + chi + pgx, con su propia PostgreSQL (`orders-db`).
- `infra/terraform/` — VPC, EKS, ECR, EBS CSI, OIDC de GitHub; `infra/terraform/argocd/` instala Argo CD y la StorageClass `gp3`.
- `.github/workflows/` — CI: test → build → push a ECR → actualiza el repo `store-gitops`.
- `../store-gitops/` — **otro repositorio git** (repo DevOps) con los manifiestos Kustomize y las Applications de Argo CD.

## 2. Estructura

```
parcial-3-nube/                 (carpeta contenedora, no es repo)
├── store-app/                  (este repo)
│   ├── AGENTS.md / CLAUDE.md
│   ├── feature_list.json       (estado de cada change: pending/in_progress/done)
│   ├── progress.md             (bitácora en español, se lee al iniciar sesión)
│   ├── init.sh                 (verifica herramientas y corre tests existentes)
│   ├── openspec/               (config.yaml, specs/, changes/)
│   ├── frontend/
│   ├── products-service/
│   ├── orders-service/
│   ├── infra/terraform/ (+ argocd/)
│   ├── scripts/                (check-capacity.py: presupuesto de pods y memoria del clúster)
│   ├── .github/workflows/ (+ scripts/)
│   ├── docs/                   (architecture.md, presentation.md, prompts.md)
│   └── docker-compose.yml
└── store-gitops/               (repo DevOps que vigila Argo CD)
    ├── apps/{frontend,products-service,orders-service,products-db,orders-db}/
    └── argocd/
```

## 3. Convenciones de idioma (obligatorio)

- **En inglés:** nombres de carpetas y archivos, código (variables, funciones, clases, tipos),
  endpoints, campos JSON, tablas y columnas, recursos de Kubernetes y Terraform, nombres de los
  changes de OpenSpec, ramas y mensajes de commit.
- **En español:** comentarios en el código, mensajes de log, mensajes de error que devuelve la API,
  texto de la interfaz del frontend, README, documentación en `docs/`, contenido de los artefactos
  de OpenSpec y tus respuestas en el chat.

## 4. Flujo de trabajo: spec-driven con OpenSpec

1. **No escribas código de una funcionalidad nueva sin un change de OpenSpec.**
2. Ciclo: `propose` → el humano revisa → `apply` → pruebas → `archive`.
3. Respeta `openspec/config.yaml` (contexto y reglas por artefacto).
4. Durante `apply`, marca cada tarea en `tasks.md` solo cuando esté hecha **y verificada**.
5. Si durante la implementación cambia el diseño, actualiza primero los specs y el design del change.
6. Si existe la skill `harness-creator`, léela al inicio de la sesión y síguela.
7. **Al iniciar sesión, lee `progress.md` y `feature_list.json`; al cerrar un change, actualízalos** (`status` y `evidence` en `feature_list.json`, nueva sección en `progress.md`). Trabaja un solo change `in_progress` a la vez. `./init.sh` verifica el entorno y corre los tests existentes.

## 5. Arquitectura GitOps: reglas que no se rompen

- Flujo: push a `main` → GitHub Actions (test, build, push a ECR con **tag = SHA corto**)
  → `kustomize edit set image` en `store-gitops` + commit → Argo CD sincroniza → EKS hace pull desde ECR.
- **Prohibido:** la etiqueta `latest`, `kubectl apply` desde la CI y access keys estáticas de AWS (usar **OIDC**).
- Patrón **database-per-service**: un servicio nunca accede a la BD del otro.
- Todo servicio expone `GET /health` → `{"status": "ok", "version": "<APP_VERSION>"}`.
- La configuración va solo por variables de entorno (12-factor).
- Los secrets **nunca** van a git (ni contraseñas de BD, ni tokens, ni `terraform.tfvars`, ni `*.tfstate`).
- Kubernetes: namespace `store`, probes en `/health`, requests/limits definidos, PostgreSQL como StatefulSet con PVC gp3.
- **Capacidad (2 × t3.small, el tipo elegido por ser elegible en el plan Gratuito de AWS):** máximo 11 pods y ~1,4 GiB asignables por nodo (22 pods en total). Una réplica por Deployment, y una por CoreDNS, el controlador EBS CSI y cada componente de Argo CD (`dex`, `notifications` y `applicationSet` apagados). Deben quedar **al menos 3 pods libres** para el rolling update. **Antes de añadir pods, réplicas o subir `requests` de memoria, ejecuta `products-service/.venv/bin/python scripts/check-capacity.py`** y no superes su presupuesto (pods libres y 70 % de la memoria asignable).

## 6. Acciones que requieren confirmación del humano

Pide confirmación antes de:
- `terraform apply` / `terraform destroy`
- `git push` (en cualquiera de los dos repos) y cualquier `git push --force`
- `kubectl apply/delete` o `helm install/uninstall` contra el clúster real
- `aws` que cree, modifique o borre recursos
- Borrar archivos o carpetas fuera del change actual

Sí puedes ejecutar libremente: tests, linters, builds locales, `docker compose`, `terraform fmt/validate/plan`,
`kubectl get/describe/logs`, `aws ... describe/list`.

## 7. Comandos por componente

| Componente | Instalar | Tests | Lint/format | Correr local |
|---|---|---|---|---|
| products-service | `pip install -r requirements.txt` | `pytest` | `ruff check . && ruff format .` | `uvicorn app.main:app --reload --port 8000` |
| orders-service | `go mod download` | `go test ./...` | `gofmt -l . && go vet ./...` | `go run ./cmd/server` |
| frontend | `npm ci` | `npm test -- --watch=false` | `npm run lint` | `npm start` |
| infra | `terraform init` | — | `terraform fmt -recursive && terraform validate` | `terraform plan` |
| todo junto | — | — | — | `docker compose up --build` |

Si un comando no existe todavía, créalo como parte del change correspondiente.

## 8. Convenciones de código

- **Python/FastAPI:** esquemas con Pydantic, capas `api/`, `models/`, `schemas/`, `db/`; tipado completo; tests con pytest.
- **Go:** layout `cmd/server`, `internal/{handler,repository,model,config}`; errores envueltos con `fmt.Errorf("...: %w", err)`; tests con `httptest`.
- **Angular:** standalone components, servicios HTTP en `core/services/`, interfaces tipadas para cada respuesta, rutas relativas `/api/...`.
- **Docker:** multi-stage, usuario no root, imagen final mínima (slim/distroless/nginx-alpine).
- **Terraform:** módulos oficiales `terraform-aws-modules`, variables con `description`, `default_tags` con `Project = "store"`.
- **Commits:** Conventional Commits en inglés (`feat(products-service): add create endpoint`).

## 9. Definición de terminado (por tarea)

- Compila y los tests pasan.
- Lint/format sin errores.
- Nombres en inglés y comentarios/mensajes en español.
- README del componente actualizado.
- La tarea está marcada en `tasks.md`.
