# frontend-proxy Specification

## Purpose
Enrutamiento de nginx hacia products-service y orders-service, publicación de la versión del frontend sin caché y empaquetado de la imagen del frontend sin root.

## Requirements

### Requirement: Enrutamiento de nginx

El nginx del frontend SHALL servir los archivos estáticos de la SPA, devolver `index.html` para cualquier ruta de la SPA que no sea un archivo ni empiece por `/api/`, y hacer de proxy así:

| Petición | Destino |
|---|---|
| `/api/products` y `/api/products/{...}` | `products-service:8000` en `/products` y `/products/{...}` |
| `/api/orders` y `/api/orders/{...}` | `orders-service:8080` en `/orders` y `/orders/{...}` |
| `/api/products/health` | `products-service:8000/health` |
| `/api/orders/health` | `orders-service:8080/health` |

#### Scenario: Productos por el proxy
- **WHEN** se hace `GET /api/products` al frontend
- **THEN** la respuesta es la de `GET /products` de `products-service`

#### Scenario: Pedidos por el proxy
- **WHEN** se hace `POST /api/orders` al frontend con un pedido válido
- **THEN** la respuesta es la de `POST /orders` de `orders-service` (201)

#### Scenario: Health por el proxy
- **WHEN** se hace `GET /api/products/health` y `GET /api/orders/health`
- **THEN** cada respuesta es `{"status": "ok", "version": "<versión del servicio>"}`

#### Scenario: Ruta de la SPA
- **WHEN** se abre `/orders` directamente en el navegador
- **THEN** nginx devuelve `index.html` con 200

### Requirement: Versión del frontend sin caché

El frontend SHALL publicar `/version.json` con `{"version": "<APP_VERSION usada al construir la imagen>"}` (valor `dev` si no se indicó) y nginx SHALL servirlo con `Cache-Control: no-store`. `index.html` SHALL servirse con `Cache-Control: no-cache`.

#### Scenario: Versión indicada al construir
- **WHEN** la imagen se construye con `--build-arg APP_VERSION=abc1234`
- **THEN** `GET /version.json` devuelve `{"version": "abc1234"}` con `Cache-Control: no-store`

#### Scenario: Versión por defecto
- **WHEN** la imagen se construye sin `APP_VERSION`
- **THEN** `GET /version.json` devuelve `{"version": "dev"}`

### Requirement: Imagen del frontend

El repositorio SHALL incluir `frontend/Dockerfile` multi-stage: una etapa con Node que construye la SPA y una etapa final con nginx que sirve el resultado con un usuario que no sea root y escucha en el puerto 8080.

#### Scenario: Usuario no root
- **WHEN** se inspecciona la imagen construida
- **THEN** su usuario configurado es distinto de root

#### Scenario: Configuración válida
- **WHEN** se ejecuta `nginx -t` con la configuración de la imagen
- **THEN** la sintaxis es correcta
