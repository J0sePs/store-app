# orders-management Specification

## Purpose
Consulta y creación de pedidos por HTTP, con persistencia en la base de datos propia del servicio, migración al arrancar y empaquetado en una imagen distroless sin root. El pedido guarda `product_id` solo como referencia.

## Requirements

### Requirement: Listar pedidos

El servicio SHALL exponer `GET /orders` y responder 200 con un arreglo JSON de pedidos ordenados por `id` ascendente. Cada pedido SHALL tener los campos `id` (entero), `product_id` (entero), `quantity` (entero), `customer` (texto), `status` (texto) y `created_at` (fecha y hora ISO 8601). Sin pedidos, el arreglo SHALL ser `[]` (nunca `null`).

#### Scenario: Con pedidos
- **WHEN** se hace `GET /orders` y existen pedidos
- **THEN** responde 200 con un arreglo cuyos elementos contienen `id`, `product_id`, `quantity`, `customer`, `status` y `created_at`

#### Scenario: Sin pedidos
- **WHEN** se hace `GET /orders` y no hay pedidos
- **THEN** responde 200 con `[]`

### Requirement: Obtener un pedido por id

El servicio SHALL exponer `GET /orders/{id}`. Si existe responde 200 con el pedido; si no existe responde 404 con `{"error": "Pedido no encontrado"}`. Un `id` que no sea un entero positivo SHALL responder 400 con `{"error": "Identificador inválido"}`.

#### Scenario: Pedido existente
- **WHEN** se hace `GET /orders/1` y existe el pedido 1
- **THEN** responde 200 con el pedido de `id` 1

#### Scenario: Pedido inexistente
- **WHEN** se hace `GET /orders/9999` y no existe
- **THEN** responde 404 con `{"error": "Pedido no encontrado"}`

#### Scenario: Id inválido
- **WHEN** se hace `GET /orders/abc`
- **THEN** responde 400 con `{"error": "Identificador inválido"}`

### Requirement: Crear un pedido

El servicio SHALL exponer `POST /orders` con cuerpo JSON `{"product_id": integer, "quantity": integer, "customer": string}`. `product_id` y `quantity` SHALL ser mayores que 0 y `customer` SHALL ser no vacío. Si el cuerpo es válido responde 201 con el pedido creado, con `status` igual a `"pending"` y `id` y `created_at` asignados por el servicio; el cliente no puede fijar `status`. Si no es válido responde 400 con `{"error": "<mensaje en español>"}` y no crea nada. El servicio NO SHALL consultar a `products-service` ni a su base de datos para validar `product_id`.

#### Scenario: Creación válida
- **WHEN** se hace `POST /orders` con `{"product_id": 1, "quantity": 2, "customer": "Ana"}`
- **THEN** responde 201 con el pedido, con `status` `"pending"`, `id` y `created_at`
- **AND** un `GET /orders/{id}` posterior devuelve ese mismo pedido

#### Scenario: Cantidad no positiva
- **WHEN** se hace `POST /orders` con `quantity` igual a 0
- **THEN** responde 400 con un mensaje de error en español y no se crea el pedido

#### Scenario: Producto no positivo
- **WHEN** se hace `POST /orders` con `product_id` igual a 0 o negativo
- **THEN** responde 400 y no se crea el pedido

#### Scenario: Cliente vacío
- **WHEN** se hace `POST /orders` con `customer` vacío o ausente
- **THEN** responde 400 y no se crea el pedido

#### Scenario: JSON mal formado
- **WHEN** se hace `POST /orders` con un cuerpo que no es JSON válido
- **THEN** responde 400 con `{"error": "<mensaje en español>"}`

#### Scenario: Estado no controlado por el cliente
- **WHEN** se hace `POST /orders` con un campo `status` igual a `"shipped"`
- **THEN** el pedido creado tiene `status` `"pending"`

### Requirement: Persistencia propia y migración al arrancar

El servicio SHALL leer la conexión a su base de datos únicamente de la variable de entorno `DATABASE_URL`. Al arrancar SHALL crear la tabla de pedidos si no existe, sin borrar datos existentes. SHALL escuchar en el puerto 8080 y no SHALL acceder a la base de datos de otro servicio. Si falta `DATABASE_URL` o la base no responde tras reintentos, SHALL terminar con un mensaje de error en español y código de salida distinto de 0.

#### Scenario: Primer arranque
- **WHEN** el servicio arranca contra una base sin tabla de pedidos
- **THEN** crea la tabla y queda atendiendo en el puerto 8080

#### Scenario: Reinicio conserva datos
- **WHEN** el servicio se reinicia y la tabla ya tiene pedidos
- **THEN** los pedidos siguen presentes y no se duplican ni se pierden

#### Scenario: Falta DATABASE_URL
- **WHEN** el servicio arranca sin `DATABASE_URL`
- **THEN** termina con código distinto de 0 y un mensaje en español que indica que falta la variable

### Requirement: Imagen de contenedor distroless

El repositorio SHALL incluir un `Dockerfile` en `orders-service/` que construya la imagen en varias etapas, con imagen final distroless que ejecute un binario estático con un usuario que no sea root y exponga el puerto 8080.

#### Scenario: Usuario no root
- **WHEN** se inspecciona la imagen construida
- **THEN** su usuario configurado es distinto de root (distinto de `0` y de vacío)

#### Scenario: Imagen sin shell
- **WHEN** se intenta ejecutar `sh` dentro de la imagen final
- **THEN** falla porque la imagen no incluye intérprete de comandos

#### Scenario: Servicio en el puerto 8080
- **WHEN** se ejecuta el contenedor con un `DATABASE_URL` válido
- **THEN** `GET /health` en el puerto 8080 responde 200 con `{"status": "ok", "version": "<APP_VERSION>"}`
