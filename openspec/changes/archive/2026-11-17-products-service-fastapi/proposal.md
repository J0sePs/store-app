## Why

El sistema necesita su primer microservicio de negocio: el catálogo de productos. Sin él no hay datos que mostrar en el frontend ni que referenciar desde pedidos. Se construye ahora porque es independiente de los demás componentes (database-per-service) y fija el patrón de `GET /health`, configuración por entorno y Dockerfile que seguirán los otros servicios.

## What Changes

- Crear `products-service/` con FastAPI, SQLAlchemy y su propia PostgreSQL (`products-db`).
- Endpoints: `GET /products`, `GET /products/{id}`, `POST /products` y `GET /health` (`{"status": "ok", "version": "<APP_VERSION>"}`).
- Modelo `Product`: `id`, `name`, `price`, `stock`, `created_at`. La tabla se crea al arrancar y, si está vacía, se siembran 3 productos de ejemplo.
- Configuración solo por variables de entorno: `DATABASE_URL` y `APP_VERSION`. Puerto 8000.
- Tests con pytest, `requirements.txt`, `Dockerfile` multi-stage con usuario no root y `README.md` en español.
- Identificadores y archivos en inglés; comentarios, logs y mensajes de error en español.
- Al cerrar el change: actualizar `feature_list.json` y `progress.md`.

Supuestos (se registran en el design): `POST /products` responde 201; la validación inválida responde 422; un id inexistente responde 404 con mensaje en español; la siembra solo ocurre si la tabla está vacía.

No hay cambios **BREAKING**.

## Capabilities

### New Capabilities

- `products-catalog`: consulta y alta de productos por HTTP, con persistencia en su propia base de datos y siembra inicial.
- `service-health`: contrato de `GET /health` que todo servicio debe cumplir (`status` y `version` desde `APP_VERSION`).

### Modified Capabilities

Ninguna. En `openspec/specs/` solo existe `project-harness`, sin relación con este change.

## Impact

- **Componente afectado:** `products-service/` (nuevo) y su base `products-db`.
- **APIs nuevas:** las 4 rutas anteriores en el puerto 8000. El frontend las consumirá más adelante vía nginx en `/api/products/`.
- **Dependencias:** `fastapi`, `uvicorn`, `sqlalchemy`, `psycopg`, `pydantic`, `pytest`, `httpx`, `ruff`.
- **Fuera de alcance:** manifiestos de Kubernetes y `docker-compose.yml` (changes posteriores); `PUT/DELETE` de productos; autenticación; migraciones con Alembic.
- **Archivos del repo:** `feature_list.json` y `progress.md` al cerrar.
