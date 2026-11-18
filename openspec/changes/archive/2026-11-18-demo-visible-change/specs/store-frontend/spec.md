## MODIFIED Requirements

### Requirement: Vista de productos

La vista de productos SHALL mostrar una tabla con una columna por cada campo visible del producto (`id`, nombre, categoría, precio, stock, fecha de creación), cada una con encabezado en español (el de la categoría es "Categoría"), y un formulario con `name`, `price`, `stock` y un campo opcional `category` ("Categoría") para crear un producto. Los campos SHALL validarse como el servicio: nombre no vacío, precio mayor que 0, stock entero mayor o igual que 0 y categoría, si se escribe, de 1 a 100 caracteres. Al crear con éxito, el producto SHALL aparecer en la tabla y el formulario SHALL limpiarse. Si un producto no trae categoría (por ejemplo, durante un despliegue con un servicio todavía en la versión anterior), la tabla SHALL mostrar "—" en esa celda.

#### Scenario: Listado
- **WHEN** se abre la vista y el servicio devuelve 3 productos
- **THEN** la tabla muestra 3 filas con sus datos, incluida su categoría

#### Scenario: Encabezado de categoría
- **WHEN** se abre la vista con productos
- **THEN** los encabezados de la tabla son "ID", "Nombre", "Categoría", "Precio", "Stock" y "Creado"

#### Scenario: Sin categoría en la respuesta
- **WHEN** el servicio devuelve productos sin el campo `category`
- **THEN** la celda de categoría de cada fila muestra "—" y la vista funciona con normalidad

#### Scenario: Lista vacía
- **WHEN** el servicio devuelve `[]`
- **THEN** se muestra el mensaje "No hay productos todavía"

#### Scenario: Creación válida
- **WHEN** el usuario completa nombre, precio y stock válidos y envía el formulario
- **THEN** se envía `POST /api/products`, el producto nuevo aparece en la tabla y el formulario queda vacío

#### Scenario: Creación con categoría
- **WHEN** el usuario completa además el campo "Categoría" con `Muebles` y envía
- **THEN** el cuerpo del `POST` incluye `category` igual a `Muebles` y la fila nueva muestra `Muebles`

#### Scenario: Categoría omitida
- **WHEN** el usuario deja vacío el campo "Categoría"
- **THEN** el cuerpo del `POST` no incluye `category` y el servicio asigna `General`

#### Scenario: Datos inválidos
- **WHEN** el precio es 0 o el nombre está vacío
- **THEN** el botón de enviar está deshabilitado o se muestra un mensaje de validación en español y no se envía nada

#### Scenario: Error del servicio
- **WHEN** el servicio responde con error o no está disponible
- **THEN** se muestra un mensaje de error en español y la aplicación sigue funcionando

## ADDED Requirements

### Requirement: Banner de versión

Todas las vistas SHALL mostrar, debajo de la barra superior y encima del contenido, un banner con el texto exacto "Versión 2 - desplegada con GitOps", en el hueco reservado `.banner-slot` del shell. El banner SHALL ser visible, con contraste suficiente y marcado como región de estado (`role="status"`) para lectores de pantalla.

#### Scenario: Banner en la vista de productos
- **WHEN** el usuario abre `/products`
- **THEN** se ve el banner con el texto "Versión 2 - desplegada con GitOps" encima del contenido

#### Scenario: Banner en la vista de pedidos
- **WHEN** el usuario navega a `/orders`
- **THEN** el banner sigue visible con el mismo texto

#### Scenario: Convive con el pie de versiones
- **WHEN** se muestra el banner
- **THEN** el pie de página sigue mostrando las versiones del frontend y de cada servicio
