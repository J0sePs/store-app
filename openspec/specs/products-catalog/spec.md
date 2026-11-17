# products-catalog Specification

## Purpose
Consulta y alta de productos por HTTP, con persistencia en la base de datos propia del servicio, siembra inicial y empaquetado en contenedor sin root.

## Requirements

### Requirement: Listar productos

El servicio SHALL exponer `GET /products` y responder 200 con un arreglo JSON de productos ordenados por `id` ascendente. Cada producto SHALL tener los campos `id` (entero), `name` (texto), `price` (número decimal), `stock` (entero) y `created_at` (fecha y hora ISO 8601).

#### Scenario: Catálogo con datos
- **WHEN** se hace `GET /products` y existen productos
- **THEN** responde 200 con un arreglo cuyos elementos contienen `id`, `name`, `price`, `stock` y `created_at`

#### Scenario: Catálogo vacío
- **WHEN** se hace `GET /products` y no hay productos
- **THEN** responde 200 con un arreglo vacío `[]`

### Requirement: Obtener un producto por id

El servicio SHALL exponer `GET /products/{id}`. Si el producto existe responde 200 con el producto; si no existe responde 404 con `{"detail": "Producto no encontrado"}`. Un `id` que no sea entero SHALL responder 422.

#### Scenario: Producto existente
- **WHEN** se hace `GET /products/1` y existe el producto 1
- **THEN** responde 200 con el producto de `id` 1

#### Scenario: Producto inexistente
- **WHEN** se hace `GET /products/9999` y no existe
- **THEN** responde 404 con `{"detail": "Producto no encontrado"}`

#### Scenario: Id inválido
- **WHEN** se hace `GET /products/abc`
- **THEN** responde 422

### Requirement: Crear un producto

El servicio SHALL exponer `POST /products` con cuerpo JSON `{"name": string, "price": number, "stock": integer}`. `name` SHALL ser no vacío; `price` SHALL ser mayor que 0; `stock` SHALL ser mayor o igual que 0. Si el cuerpo es válido responde 201 con el producto creado, que incluye `id` y `created_at` asignados por el servicio. Si no es válido responde 422 y no crea nada.

#### Scenario: Creación válida
- **WHEN** se hace `POST /products` con `{"name": "Teclado", "price": 25.5, "stock": 10}`
- **THEN** responde 201 con el producto, que incluye `id` y `created_at`
- **AND** un `GET /products/{id}` posterior devuelve ese mismo producto

#### Scenario: Precio no positivo
- **WHEN** se hace `POST /products` con `price` igual a 0 o negativo
- **THEN** responde 422 y el producto no se crea

#### Scenario: Stock negativo
- **WHEN** se hace `POST /products` con `stock` igual a -1
- **THEN** responde 422 y el producto no se crea

#### Scenario: Campo obligatorio ausente
- **WHEN** se hace `POST /products` sin `name`
- **THEN** responde 422 y el producto no se crea

### Requirement: Persistencia propia y arranque

El servicio SHALL leer la conexión a su base de datos únicamente de la variable de entorno `DATABASE_URL`. Al arrancar SHALL crear la tabla de productos si no existe y, solo si la tabla está vacía, SHALL insertar 3 productos de ejemplo. El servicio SHALL escuchar en el puerto 8000 y no SHALL acceder a la base de datos de otro servicio.

#### Scenario: Primer arranque
- **WHEN** el servicio arranca contra una base sin tabla de productos
- **THEN** crea la tabla e inserta exactamente 3 productos de ejemplo

#### Scenario: Reinicio sin duplicar
- **WHEN** el servicio se reinicia y la tabla ya tiene productos
- **THEN** no inserta productos adicionales

#### Scenario: Falta DATABASE_URL
- **WHEN** el servicio arranca sin `DATABASE_URL`
- **THEN** termina con un mensaje de error en español que indica que falta la variable

### Requirement: Imagen de contenedor

El repositorio SHALL incluir un `Dockerfile` en `products-service/` que construya la imagen en varias etapas, que ejecute el proceso con un usuario que no sea root y que exponga el puerto 8000.

#### Scenario: Usuario no root
- **WHEN** se construye la imagen y se ejecuta `id -u` dentro del contenedor
- **THEN** el resultado es distinto de 0

#### Scenario: Servicio en el puerto 8000
- **WHEN** se ejecuta el contenedor con un `DATABASE_URL` válido
- **THEN** `GET /health` en el puerto 8000 responde 200
