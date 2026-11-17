# Tasks

## 1. Estado y andamiaje

- [x] 1.1 Marcar `products-service-fastapi` como `in_progress` en `feature_list.json`; verificar con `./init.sh` que solo hay un change activo
- [x] 1.2 Crear `products-service/` con `requirements.txt`, `requirements-dev.txt`, `pyproject.toml` (config de `ruff` y `pytest`) y `.dockerignore`; crear un venv local con `python3 -m venv products-service/.venv` e instalar dependencias; verificar con `pip list` que están `fastapi`, `sqlalchemy`, `psycopg`, `pytest`, `httpx` y `ruff`
- [x] 1.3 Verificar que `products-service/.venv/` queda ignorado por `.gitignore` con `git check-ignore products-service/.venv`

## 2. Configuración y base de datos

- [x] 2.1 Implementar `app/config.py` (`DATABASE_URL`, `APP_VERSION` con valor por defecto `dev`, error en español si falta `DATABASE_URL`); verificar con tests de configuración (variable definida, ausente y versión por defecto)
- [x] 2.2 Implementar `app/db/` (engine, `SessionLocal`, dependencia de sesión, `Base`) y `app/models/product.py` con `Product` (`id`, `name`, `price` `Numeric(10,2)`, `stock`, `created_at`); verificar con un test que crea la tabla en SQLite y guarda un producto
- [x] 2.3 Implementar la siembra idempotente de 3 productos y el reintento de conexión (3 intentos, 2 s) en el arranque; verificar con tests: tabla vacía → 3 productos, segundo arranque → sigue habiendo 3

## 3. API

- [x] 3.1 Implementar `app/schemas/product.py` (`ProductCreate` con `name` no vacío, `price > 0`, `stock >= 0`; `ProductRead`); verificar con tests de validación (precio 0, stock -1, nombre ausente → 422)
- [x] 3.2 Implementar `GET /products` y `GET /products/{id}` en `app/api/` con 404 `{"detail": "Producto no encontrado"}`; verificar con tests: lista ordenada por `id`, lista vacía, producto existente, 404 e id `abc` → 422
- [x] 3.3 Implementar `POST /products` con 201; verificar con tests: creación válida devuelve `id` y `created_at`, y un `GET` posterior devuelve el mismo producto
- [x] 3.4 Implementar `GET /health` sin acceso a la BD y `app/main.py` con `lifespan` (crear tabla, sembrar) y logs en español; verificar con tests de `/health` con `APP_VERSION=1.2.3` y sin definir (`dev`)
- [x] 3.5 Ejecutar `ruff check . && ruff format .` y `pytest` en `products-service/`; verificar que ambos terminan sin errores y que todos los escenarios de los specs tienen un test

## 4. Contenedor y verificación con PostgreSQL

- [x] 4.1 Crear el `Dockerfile` multi-stage con usuario no root (uid 10001), `EXPOSE 8000` y `uvicorn`; verificar con `docker build -t products-service:dev products-service/` y `docker run --rm products-service:dev id -u` distinto de 0
- [x] 4.2 Probar contra PostgreSQL real: red Docker temporal, contenedor `postgres:16-alpine` con credenciales de prueba pasadas por variable de entorno (no se guardan en git) y el servicio; verificar con `curl` que `/health`, `GET /products` (3 productos sembrados), `POST /products` y `GET /products/1` responden como en los specs, y que un reinicio no duplica la siembra; limpiar contenedores y red al terminar

## 5. Documentación y cierre

- [x] 5.1 Escribir `products-service/README.md` en español (variables de entorno, endpoints con ejemplos `curl`, cómo correr tests, `ruff`, `docker build/run`); verificar que los comandos documentados corren tal cual
- [x] 5.2 Actualizar la sección 2 de `AGENTS.md` solo si cambia algo de la estructura, y confirmar con `./init.sh` que ahora ejecuta `pytest` de `products-service` y pasa; verificar salida con código 0
- [x] 5.3 Ejecutar `openspec validate products-service-fastapi` y verificar nombres de archivos e identificadores en inglés y comentarios/logs/errores en español (revisión manual)
- [x] 5.4 Cerrar el change: `feature_list.json` con `products-service-fastapi` en `done` y `evidence` (tests, `ruff`, `docker`, `curl`), y nueva sección en `progress.md` con siguiente paso `orders-service-go`; verificar que `orders-service-go` queda `pending`

## Workflow follow-up

- Archivar con `/openspec-archive-change` tras la revisión del humano.
- No hacer commit ni `git push` sin confirmación.
