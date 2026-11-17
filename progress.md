# Bitácora de progreso — store-app

> Cualquier agente (Claude Code, opencode) debe leer este archivo y `feature_list.json` al iniciar sesión.
> Al cerrar un change se agrega una sección nueva al final (la más reciente al final) y se actualiza `feature_list.json`.

## Estado actual

- **Change activo:** ninguno (`products-service-fastapi` terminado, archivado y con commit)
- **Siguiente paso:** proponer `orders-service-go` (`change-2`) con `/openspec-propose orders-service-go` y el prompt de `docs/prompts.md`, cuando el humano lo pida.
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
