# orders-service

Microservicio de pedidos del proyecto `store-app`. Está escrito en Go con chi y pgx, y usa su propia base PostgreSQL (`orders-db`); ningún otro servicio accede a ella.

> **`product_id` es solo una referencia.** Este servicio no consulta a `products-service` ni a su base de datos, así que no comprueba que el producto exista (patrón database-per-service).

## Variables de entorno

| Variable | Obligatoria | Descripción |
|---|---|---|
| `DATABASE_URL` | Sí | URL de conexión, p. ej. `postgres://usuario:clave@host:5432/orders?sslmode=disable` |
| `APP_VERSION` | No | Versión que devuelve `/health`. Por defecto `dev` |

Si falta `DATABASE_URL`, el servicio termina con código 1 y el mensaje `falta la variable de entorno DATABASE_URL`. Si la base no responde, reintenta 5 veces (cada 2 s) antes de terminar.

## Endpoints (puerto 8080)

| Método | Ruta | Respuesta |
|---|---|---|
| GET | `/health` | `200 {"status": "ok", "version": "<APP_VERSION>"}` |
| GET | `/orders` | `200` lista ordenada por `id` (`[]` si no hay pedidos) |
| GET | `/orders/{id}` | `200` pedido, `404 {"error": "Pedido no encontrado"}`, `400 {"error": "Identificador inválido"}` |
| POST | `/orders` | `201` pedido creado con `status` `pending`; `400` si los datos no son válidos |

Pedido: `id`, `product_id`, `quantity`, `customer`, `status`, `created_at`. En `POST` se envían `product_id` (> 0), `quantity` (> 0) y `customer` (no vacío). El `status` lo fija el servicio: si el cliente lo envía, se ignora.

**Formato de error:** `{"error": "<mensaje en español>"}`. `products-service` usa `{"detail": "..."}`, así que el cliente debe leer ambos campos.

Al arrancar se crea la tabla `orders` si no existe (migración idempotente; no borra datos).

```bash
curl http://localhost:8080/health
curl http://localhost:8080/orders
curl http://localhost:8080/orders/1
curl -X POST http://localhost:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{"product_id": 1, "quantity": 2, "customer": "Ana"}'
```

## Desarrollo local

```bash
cd orders-service
go mod download
export DATABASE_URL='postgres://usuario:clave@localhost:5432/orders?sslmode=disable'
go run ./cmd/server
```

## Pruebas y calidad

Los tests usan `httptest` y un almacén en memoria; no necesitan PostgreSQL ni Docker.

```bash
go test ./...
gofmt -l . && go vet ./...
```

## Docker

La imagen es multi-stage: compila un binario estático y lo copia a una imagen `distroless` sin shell, con el usuario `65532` (sin privilegios).

```bash
docker build -t orders-service:dev .
docker run --rm -p 8080:8080 \
  -e DATABASE_URL='postgres://usuario:clave@host:5432/orders?sslmode=disable' \
  -e APP_VERSION=0.1.0 \
  orders-service:dev
```

Como la imagen no tiene shell ni `curl`, las comprobaciones se hacen desde fuera (por ejemplo, con un contenedor `curlimages/curl` en la misma red). Las credenciales reales no se guardan en git: se inyectan por variable de entorno o como Secret de Kubernetes.

## Estructura

```
cmd/server/            # punto de entrada: configuración, migración, servidor y apagado ordenado
internal/
├── config/            # variables de entorno
├── handler/           # rutas HTTP (chi) e interfaz OrderStore
├── model/             # Order, validación de la entrada y errores
└── repository/        # acceso a PostgreSQL con pgx y migración SQL embebida
```
