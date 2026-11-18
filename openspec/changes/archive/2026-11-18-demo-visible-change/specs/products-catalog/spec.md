## MODIFIED Requirements

### Requirement: Listar productos

El servicio SHALL exponer `GET /products` y responder 200 con un arreglo JSON de productos ordenados por `id` ascendente. Cada producto SHALL tener los campos `id` (entero), `name` (texto), `category` (texto), `price` (número decimal), `stock` (entero) y `created_at` (fecha y hora ISO 8601). `GET /products/{id}` SHALL devolver los mismos campos.

#### Scenario: Catálogo con datos
- **WHEN** se hace `GET /products` y existen productos
- **THEN** responde 200 con un arreglo cuyos elementos contienen `id`, `name`, `category`, `price`, `stock` y `created_at`

#### Scenario: Catálogo vacío
- **WHEN** se hace `GET /products` y no hay productos
- **THEN** responde 200 con un arreglo vacío `[]`

#### Scenario: Categoría en el detalle
- **WHEN** se hace `GET /products/1` y existe el producto 1
- **THEN** la respuesta incluye el campo `category` con un texto no vacío

### Requirement: Crear un producto

El servicio SHALL exponer `POST /products` con cuerpo JSON `{"name": string, "price": number, "stock": integer, "category": string}`. `name` SHALL ser no vacío; `price` SHALL ser mayor que 0; `stock` SHALL ser mayor o igual que 0; `category` es opcional y, si se envía, SHALL tener entre 1 y 100 caracteres (sin contar espacios iniciales y finales); si se omite, SHALL valer `General`. Si el cuerpo es válido responde 201 con el producto creado, que incluye `id`, `category` y `created_at` asignados por el servicio. Si no es válido responde 422 y no crea nada.

#### Scenario: Creación válida
- **WHEN** se hace `POST /products` con `{"name": "Teclado", "price": 25.5, "stock": 10}`
- **THEN** responde 201 con el producto, que incluye `id`, `created_at` y `category` igual a `General`
- **AND** un `GET /products/{id}` posterior devuelve ese mismo producto

#### Scenario: Creación con categoría
- **WHEN** se hace `POST /products` con `{"name": "Silla", "price": 80, "stock": 3, "category": "Muebles"}`
- **THEN** responde 201 con `category` igual a `Muebles` y un `GET /products/{id}` posterior devuelve `Muebles`

#### Scenario: Categoría inválida
- **WHEN** se hace `POST /products` con `category` vacío, solo con espacios o de más de 100 caracteres
- **THEN** responde 422 y el producto no se crea

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

El servicio SHALL leer la conexión a su base de datos únicamente de la variable de entorno `DATABASE_URL`. Al arrancar SHALL crear la tabla de productos si no existe, SHALL aplicar una migración idempotente que añade la columna `category` a una tabla ya existente que no la tenga, y, solo si la tabla está vacía, SHALL insertar 3 productos de ejemplo. En PostgreSQL la migración SHALL ser `ALTER TABLE products ADD COLUMN IF NOT EXISTS category VARCHAR(100) NOT NULL DEFAULT 'General'`: los productos existentes conservan todos sus datos y reciben `General`. La columna SHALL tener un valor por defecto para que una versión anterior del servicio siga funcionando contra la base ya migrada. El servicio SHALL escuchar en el puerto 8000 y no SHALL acceder a la base de datos de otro servicio.

#### Scenario: Primer arranque
- **WHEN** el servicio arranca contra una base sin tabla de productos
- **THEN** crea la tabla con la columna `category` e inserta exactamente 3 productos de ejemplo, cada uno con una categoría

#### Scenario: Reinicio sin duplicar
- **WHEN** el servicio se reinicia y la tabla ya tiene productos
- **THEN** no inserta productos adicionales

#### Scenario: Falta DATABASE_URL
- **WHEN** el servicio arranca sin `DATABASE_URL`
- **THEN** termina con un mensaje de error en español que indica que falta la variable

#### Scenario: Base existente sin la columna
- **WHEN** el servicio arranca contra una base cuya tabla `products` ya existe con datos y sin la columna `category`
- **THEN** añade la columna, los productos existentes conservan `id`, `name`, `price`, `stock` y `created_at`, y todos tienen `category` igual a `General`

#### Scenario: Migración idempotente
- **WHEN** el servicio arranca de nuevo contra una base que ya tiene la columna `category`
- **THEN** no falla, no cambia las categorías existentes y no duplica ni borra datos

#### Scenario: Versión anterior sobre la base migrada
- **WHEN** la versión anterior del servicio (sin `category`) lee y crea productos contra la base ya migrada
- **THEN** funciona sin errores y los productos que crea reciben `category` igual a `General`
