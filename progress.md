# Bitácora de progreso — store-app

> Cualquier agente (Claude Code, opencode) debe leer este archivo y `feature_list.json` al iniciar sesión.
> Al cerrar un change se agrega una sección nueva al final (la más reciente al final) y se actualiza `feature_list.json`.

## Estado actual

- **Change activo:** ninguno (`orders-service-go` terminado, archivado y con commit)
- **Siguiente paso:** proponer `frontend-angular` (`change-3`, incluye `docker-compose.yml`) con `/openspec-propose frontend-angular` y el prompt de `docs/prompts.md`, cuando el humano lo pida.
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
