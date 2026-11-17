## ADDED Requirements

### Requirement: Navegación y textos en español

La aplicación SHALL tener una barra de navegación con enlaces a "Productos" y "Pedidos", mostrar la vista de productos como ruta inicial y mostrar todo el texto visible al usuario en español. Las llamadas HTTP SHALL usar rutas relativas (`/api/products`, `/api/orders`).

#### Scenario: Ruta inicial
- **WHEN** el usuario abre `/`
- **THEN** ve la vista de productos

#### Scenario: Navegar a pedidos
- **WHEN** el usuario hace clic en "Pedidos"
- **THEN** ve la vista de pedidos sin recargar la página

#### Scenario: Llamadas relativas
- **WHEN** la aplicación consulta productos
- **THEN** la petición va a `/api/products` del mismo origen

### Requirement: Vista de productos

La vista de productos SHALL mostrar una tabla con una columna por cada campo visible del producto (`id`, nombre, precio, stock, fecha de creación), cada una con encabezado en español, y un formulario con `name`, `price` y `stock` para crear un producto. Los campos SHALL validarse como el servicio: nombre no vacío, precio mayor que 0, stock entero mayor o igual que 0. Al crear con éxito, el producto SHALL aparecer en la tabla y el formulario SHALL limpiarse.

#### Scenario: Listado
- **WHEN** se abre la vista y el servicio devuelve 3 productos
- **THEN** la tabla muestra 3 filas con sus datos

#### Scenario: Lista vacía
- **WHEN** el servicio devuelve `[]`
- **THEN** se muestra el mensaje "No hay productos todavía"

#### Scenario: Creación válida
- **WHEN** el usuario completa nombre, precio y stock válidos y envía el formulario
- **THEN** se envía `POST /api/products`, el producto nuevo aparece en la tabla y el formulario queda vacío

#### Scenario: Datos inválidos
- **WHEN** el precio es 0 o el nombre está vacío
- **THEN** el botón de enviar está deshabilitado o se muestra un mensaje de validación en español y no se envía nada

#### Scenario: Error del servicio
- **WHEN** el servicio responde con error o no está disponible
- **THEN** se muestra un mensaje de error en español y la aplicación sigue funcionando

### Requirement: Vista de pedidos

La vista de pedidos SHALL mostrar una tabla con los pedidos (`id`, producto, cantidad, cliente, estado, fecha) y un formulario para crear un pedido con `customer`, `quantity` y un selector de producto cuyas opciones provienen de la lista de productos. El pedido SHALL enviarse con `product_id` del producto elegido. La tabla SHALL mostrar el nombre del producto cuando está en la lista y "Producto #<id>" cuando no lo está.

#### Scenario: Selector de productos
- **WHEN** se abre la vista de pedidos y hay productos
- **THEN** el selector ofrece una opción por cada producto, con su nombre

#### Scenario: Creación válida
- **WHEN** el usuario elige un producto, indica cantidad mayor que 0 y cliente no vacío, y envía
- **THEN** se envía `POST /api/orders` con `product_id`, `quantity` y `customer`, y el pedido nuevo aparece en la tabla con estado `pending`

#### Scenario: Sin productos
- **WHEN** no hay productos en la lista
- **THEN** el formulario muestra "Primero crea un producto" y no permite enviar

#### Scenario: Producto desconocido
- **WHEN** un pedido referencia un `product_id` que no está en la lista de productos
- **THEN** la tabla muestra "Producto #<id>"

#### Scenario: Error de validación del servicio
- **WHEN** `orders-service` responde 400 con `{"error": "<mensaje>"}`
- **THEN** se muestra ese mensaje al usuario

### Requirement: Normalización de errores

El frontend SHALL traducir las respuestas de error de ambos servicios a un único mensaje en español: `{"detail": "<texto>"}` y `{"error": "<texto>"}` muestran el texto, una lista `detail` de validación (422) muestra un mensaje genérico de datos inválidos, y los errores de red o 5xx muestran "No se pudo conectar con el servicio".

#### Scenario: Formato detail
- **WHEN** `products-service` responde 404 `{"detail": "Producto no encontrado"}`
- **THEN** el mensaje mostrado es "Producto no encontrado"

#### Scenario: Formato error
- **WHEN** `orders-service` responde 400 `{"error": "quantity debe ser mayor que 0"}`
- **THEN** el mensaje mostrado es "quantity debe ser mayor que 0"

#### Scenario: Error de red
- **WHEN** la petición falla sin respuesta o con estado 5xx
- **THEN** el mensaje mostrado es "No se pudo conectar con el servicio"

### Requirement: Pie de página con versiones

Toda vista SHALL mostrar un pie de página con la versión del frontend y la versión de cada servicio. La versión del frontend SHALL leerse de `/version.json` (campo `version`). La de cada servicio SHALL leerse de `GET /api/products/health` y `GET /api/orders/health` (campo `version`). Si un servicio no responde, el pie SHALL mostrar "no disponible" para ese servicio sin afectar al resto. Las versiones SHALL consultarse cada vez que se carga la aplicación y cada 30 segundos.

#### Scenario: Todas las versiones
- **WHEN** los tres orígenes responden con versiones `1.0.0`, `1.0.1` y `1.0.2`
- **THEN** el pie muestra las tres versiones, etiquetadas como Frontend, Productos y Pedidos

#### Scenario: Servicio caído
- **WHEN** `orders-service` no responde
- **THEN** el pie muestra "no disponible" en Pedidos y las demás versiones siguen visibles

#### Scenario: Cambio de versión visible
- **WHEN** un servicio se despliega con una versión nueva
- **THEN** el pie muestra la versión nueva en la siguiente consulta, sin recargar la página
