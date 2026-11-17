## Why

Los dos servicios ya existen pero no hay interfaz para usarlos. El frontend es lo que se verá en el video de la demo de GitOps: debe consumir ambos servicios y mostrar, en el pie de página, la versión del frontend y la de cada servicio. También se necesita `docker-compose.yml` para probar todo el sistema en local, sin AWS, antes de tocar la infraestructura.

## What Changes

- Crear `frontend/` con Angular (standalone components, rutas relativas `/api/...`). Componentes en inglés (`products-page`, `orders-page`, `version-footer`, `app-shell`); texto visible en español.
- Vista de productos: tabla con listado y formulario para crear.
- Vista de pedidos: tabla con listado y formulario para crear, eligiendo el producto de una lista cargada desde `products-service`.
- Pie de página `version-footer`: versión del frontend y de cada servicio (consulta `/health`); si un servicio no responde, lo indica.
- `nginx.conf`: sirve la SPA y hace de proxy: `/api/products` → `products-service:8000`, `/api/orders` → `orders-service:8080` (y sus `/health`).
- `Dockerfile` multi-stage (build con Node, servido con nginx no root). La versión del frontend se fija al construir la imagen (`APP_VERSION`, que CI llenará con el SHA).
- `docker-compose.yml` en la raíz: `frontend`, `products-service`, `products-db`, `orders-service`, `orders-db`. Las contraseñas vienen de un `.env` local (con `.env.example` versionado) y no van a git.
- Pruebas unitarias, lint y `README.md` en español.
- Al cerrar el change: actualizar `feature_list.json` y `progress.md`.

Supuestos (se detallan en el design): el frontend normaliza los errores de ambos servicios (`detail` y `error`); la tabla de productos usa encabezados de columna, porque el change de demo añadirá una columna "Categoría"; no hay autenticación ni edición/borrado.

No hay cambios **BREAKING**.

## Capabilities

### New Capabilities

- `store-frontend`: vistas de productos y pedidos, formularios, manejo de errores y pie de página con versiones, todo en español.
- `frontend-proxy`: contrato de enrutamiento de nginx hacia los servicios y empaquetado de la imagen del frontend.
- `local-stack`: ejecución de todo el sistema en local con `docker compose`.

### Modified Capabilities

Ninguna. Los specs `products-catalog`, `orders-management` y `service-health` no cambian: el frontend solo los consume.

## Impact

- **Componentes afectados:** `frontend/` (nuevo) y `docker-compose.yml` (nuevo). Los servicios no se modifican.
- **Dependencias:** Angular, `@angular/cli`, angular-eslint, nginx (imagen), Node (solo para construir), PostgreSQL 16 en compose.
- **Fuera de alcance:** manifiestos de Kubernetes, CI, edición o borrado, autenticación, e2e en navegador, pasar `APP_VERSION` a las imágenes de los servicios (change de CI).
- **Archivos del repo:** `.env.example`, `README.md` raíz, `feature_list.json` y `progress.md`.
