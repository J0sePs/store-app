# frontend

Interfaz web de `store-app`, hecha con Angular (standalone components) y servida con nginx. Consume los dos servicios a través del mismo origen: `/api/products` y `/api/orders`.

## Qué incluye

- **Productos:** tabla y formulario para crear (nombre, precio, stock).
- **Pedidos:** tabla y formulario para crear, eligiendo el producto de una lista. El nombre del producto se resuelve en el frontend, porque el pedido solo guarda `product_id` (si no está en la lista se muestra `Producto #id`).
- **Pie de página:** versión del frontend y de cada servicio. Se actualiza solo cada 30 segundos y muestra `no disponible` si un servicio no responde.
- **Errores:** se traducen a un único mensaje en español (`products-service` responde `{"detail": ...}` y `orders-service` `{"error": ...}`).

## Estructura

```
src/app/
├── core/
│   ├── models/        # interfaces de cada respuesta
│   ├── services/      # servicios HTTP (products, orders, health, version)
│   └── errors/        # to-user-message: normaliza los errores de ambos servicios
├── features/
│   ├── products/      # products-page
│   └── orders/        # orders-page
└── shared/
    ├── app-shell/     # navegación, contenido y pie
    └── version-footer/
```

## Desarrollo

```bash
cd frontend
npm ci
npm start                   # http://localhost:4200
```

`npm start` no incluye el proxy: para probar con datos reales usa `docker compose` desde la raíz del repo.

## Pruebas y calidad

Las pruebas usan Vitest con jsdom (no necesitan navegador).

```bash
npm test -- --watch=false
npm run lint
npm run build
```

## nginx

`nginx.conf` sirve la SPA y hace de proxy. El prefijo `/api` se quita y se conserva el recurso:

| Petición | Destino |
|---|---|
| `/api/products`, `/api/products/{id}` | `products-service:8000/products`, `/products/{id}` |
| `/api/orders`, `/api/orders/{id}` | `orders-service:8080/orders`, `/orders/{id}` |
| `/api/products/health` | `products-service:8000/health` |
| `/api/orders/health` | `orders-service:8080/health` |

Cualquier otra ruta `/api/...` devuelve 404, y las rutas de la SPA (`/orders`, etc.) devuelven `index.html`.

El propio frontend expone `GET /health` → `{"status": "ok", "version": "<APP_VERSION>"}` (con `Cache-Control: no-store`). No consulta a los servicios, así que responde 200 aunque estén caídos: es la probe de Kubernetes (readiness y liveness). nginx resuelve los nombres `products-service` y `orders-service` al arrancar, así que deben existir en la red (en `docker compose` y en Kubernetes).

## Docker

La imagen es multi-stage: Node construye la SPA y `nginx-unprivileged` la sirve en el puerto 8080 con un usuario sin privilegios.

```bash
docker build --build-arg APP_VERSION=abc1234 -t frontend:dev .
docker run --rm -p 8080:8080 frontend:dev
```

`APP_VERSION` (por defecto `dev`) se fija al construir y se publica en `/version.json` y en `/health`, que nginx sirve con `Cache-Control: no-store`. Solo admite letras, números, punto, guion y guion bajo. CI pasará aquí el SHA corto de la imagen.
