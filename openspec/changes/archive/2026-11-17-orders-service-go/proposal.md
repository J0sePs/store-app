## Why

El sistema necesita su segundo microservicio de negocio: los pedidos. Con `products-service` ya construido, `orders-service` completa la API que consumirá el frontend y demuestra el patrón database-per-service con otro lenguaje (Go): un pedido guarda solo una referencia al producto, sin consultar al otro servicio ni a su base de datos.

## What Changes

- Crear `orders-service/` en Go con chi y pgx, con su propia PostgreSQL (`orders-db`).
- Endpoints: `GET /orders`, `GET /orders/{id}`, `POST /orders` y `GET /health` (`{"status": "ok", "version": "<APP_VERSION>"}`), este último según el spec `service-health` ya existente.
- Modelo `Order`: `id`, `product_id` (solo referencia), `quantity`, `customer`, `status`, `created_at`.
- Migración al arrancar (la tabla se crea si no existe). Configuración solo por entorno: `DATABASE_URL` y `APP_VERSION`. Puerto 8080.
- Tests con `go test` y `httptest`, `Dockerfile` multi-stage con imagen final distroless y `README.md` en español.
- Identificadores y archivos en inglés; comentarios, logs y mensajes de error en español.
- Al cerrar el change: actualizar `feature_list.json` y `progress.md`.

Supuestos (se detallan en el design): `POST /orders` responde 201 y crea el pedido con `status` = `pending` (el cliente no lo envía); `product_id` y `quantity` deben ser enteros mayores que 0 y `customer` no puede estar vacío (400 si no); el servicio no valida que el producto exista; no se siembran datos.

No hay cambios **BREAKING**.

## Capabilities

### New Capabilities

- `orders-management`: consulta y creación de pedidos por HTTP, con persistencia en su propia base de datos, migración al arrancar y empaquetado en contenedor distroless.

### Modified Capabilities

Ninguna. `service-health` ya exige `GET /health` a todo servicio, así que `orders-service` lo cumple sin cambiar el requisito.

## Impact

- **Componente afectado:** `orders-service/` (nuevo) y su base `orders-db`.
- **APIs nuevas:** las 4 rutas anteriores en el puerto 8080. El frontend las consumirá más adelante vía nginx en `/api/orders/`.
- **Dependencias Go:** `github.com/go-chi/chi/v5` y `github.com/jackc/pgx/v5`; solo biblioteca estándar para tests.
- **Fuera de alcance:** manifiestos de Kubernetes, `docker-compose.yml`, validar el producto contra `products-service`, actualizar o cancelar pedidos, autenticación.
- **Archivos del repo:** `feature_list.json` y `progress.md` al cerrar.
