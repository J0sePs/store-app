## ADDED Requirements

### Requirement: Health del frontend

El nginx del frontend SHALL responder `GET /health` con 200 y `{"status": "ok", "version": "<APP_VERSION usada al construir la imagen>"}` (valor `dev` si no se indicó), con `Cache-Control: no-store`, sin depender de ningún servicio. La ruta SHALL responder aunque `products-service` u `orders-service` no estén disponibles, para poder usarla como probe de Kubernetes.

#### Scenario: Versión indicada al construir
- **WHEN** la imagen se construye con `--build-arg APP_VERSION=abc1234` y se hace `GET /health`
- **THEN** responde 200 con `{"status": "ok", "version": "abc1234"}` y `Cache-Control: no-store`

#### Scenario: Versión por defecto
- **WHEN** la imagen se construye sin `APP_VERSION`
- **THEN** `GET /health` devuelve `"version": "dev"`

#### Scenario: Independiente de los servicios
- **WHEN** `products-service` y `orders-service` no responden y se hace `GET /health` al frontend
- **THEN** responde 200
