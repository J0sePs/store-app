## ADDED Requirements

### Requirement: Endpoint de salud

Todo servicio SHALL exponer `GET /health` y responder 200 con `{"status": "ok", "version": "<APP_VERSION>"}`, donde `version` toma el valor de la variable de entorno `APP_VERSION`. Si `APP_VERSION` no está definida, `version` SHALL ser `"dev"`. Este change lo cumple en `products-service`.

#### Scenario: Versión definida
- **WHEN** `APP_VERSION=1.2.3` y se hace `GET /health`
- **THEN** responde 200 con `{"status": "ok", "version": "1.2.3"}`

#### Scenario: Versión sin definir
- **WHEN** `APP_VERSION` no está definida y se hace `GET /health`
- **THEN** responde 200 con `{"status": "ok", "version": "dev"}`

#### Scenario: Salud sin consultar datos
- **WHEN** se hace `GET /health` y la lista de productos está vacía
- **THEN** responde 200 igualmente
