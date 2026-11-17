# Tasks

## 1. Estado y andamiaje

- [x] 1.1 Marcar `frontend-angular` como `in_progress` en `feature_list.json`; verificar con `./init.sh` que solo hay un change activo
- [x] 1.2 Crear `frontend/` con `npx @angular/cli@22 new frontend --skip-git --style=css --routing --ssr=false` (standalone) y confirmar que compila; verificar con `npm run build` y `npm test -- --watch=false` sin errores, anotando el ejecutor de pruebas que usa la CLI
- [x] 1.3 Añadir `angular-eslint` y el script `npm run lint`; verificar que `npm run lint` pasa y que `node_modules/`, `dist/` y `.angular/` quedan ignorados con `git check-ignore`

## 2. Núcleo: modelos, servicios y errores

- [x] 2.1 Crear en `src/app/core/models` las interfaces `Product`, `CreateProductRequest`, `Order`, `CreateOrderRequest` y `HealthResponse`; verificar con `npm run build` sin errores de tipos
- [x] 2.2 Implementar `core/services/products.service.ts`, `orders.service.ts` y `health.service.ts` con rutas relativas (`/api/products`, `/api/orders`, `/api/products/health`, `/api/orders/health`); verificar con tests de `HttpTestingController` que cada llamada usa el método y la URL correctos
- [x] 2.3 Implementar `toUserMessage` (formatos `detail`, `error`, lista de validación, red y 5xx); verificar con un test de tabla que cubre los 5 casos del spec
- [x] 2.4 Implementar `VersionService` (frontend desde `/version.json`, servicios desde `/health`, consulta inmediata y cada 30 s, fallo aislado por origen); verificar con tests: todas las versiones, un servicio caído, y cambio de versión en la siguiente consulta con tiempo simulado

## 3. Vista de productos

- [x] 3.1 Implementar `features/products/products-page` con tabla (`<th>` por columna, en español), mensaje "No hay productos todavía" y mensaje de error; verificar con tests de componente: 3 filas, lista vacía y error del servicio
- [x] 3.2 Añadir el formulario de alta con validación (nombre requerido, precio ≥ 0,01, stock entero ≥ 0), limpieza tras crear y refresco de la tabla; verificar con tests: creación válida llama a `POST /api/products` y añade la fila, y datos inválidos no envían nada

## 4. Vista de pedidos

- [x] 4.1 Implementar `features/orders/orders-page` con tabla (producto por nombre o "Producto #id") cargando productos y pedidos en paralelo; verificar con tests: nombres resueltos, producto desconocido y lista vacía
- [x] 4.2 Añadir el formulario de alta con selector de producto, cantidad y cliente, mensaje "Primero crea un producto" sin productos y mensaje del servicio ante un 400; verificar con tests: `POST /api/orders` con `product_id` elegido, formulario bloqueado sin productos y error `{"error": ...}` mostrado

## 5. Shell, rutas y pie de página

- [x] 5.1 Implementar `shared/version-footer` (Frontend, Productos y Pedidos, con "no disponible") y `app-shell` con navegación "Productos" / "Pedidos", `router-outlet` y rutas (`/` → productos); verificar con tests: tres versiones, servicio caído, y navegación a pedidos
- [x] 5.2 Aplicar estilos básicos legibles (tablas, formularios, pie fijo y espacio reservado para el banner de la demo) y revisar que todo el texto visible está en español; verificar con `npm run build` y `npm run lint` sin errores

## 6. nginx y Dockerfile

- [x] 6.1 Escribir `frontend/nginx.conf` (SPA con `try_files`, proxy `/api/products` y `/api/orders`, `location =` para los dos `/health`, cachés de `version.json` e `index.html`, gzip, `nosniff`); verificar con `docker run --rm` de la imagen oficial ejecutando `nginx -t` con ese archivo
- [x] 6.2 Escribir `frontend/Dockerfile` multi-stage (Node para construir, `nginx-unprivileged` para servir, `ARG APP_VERSION` validado que genera `version.json`) y `.dockerignore`; verificar con `docker build --build-arg APP_VERSION=abc1234` que `GET /version.json` devuelve `{"version":"abc1234"}` con `Cache-Control: no-store`, que sin el argumento devuelve `dev`, y que el usuario de la imagen no es root

## 7. docker-compose

- [x] 7.1 Escribir `docker-compose.yml` (cinco servicios, healthchecks, volúmenes, solo el frontend publicado, variables de versión) y `.env.example`; verificar con `docker compose --env-file .env.example config` válido, que sin `.env` falla con el mensaje en español, y con `git check-ignore .env` / `git check-ignore .env.example` (el primero ignorado, el segundo no)
- [x] 7.2 Probar el sistema completo: `cp .env.example .env` y `docker compose up --build -d`; verificar con `curl` por el puerto del frontend que `/`, `/orders`, `/version.json`, `/api/products/health` y `/api/orders/health` responden 200, que se puede crear un producto y un pedido por `/api/...`, y que tras `docker compose restart` los datos siguen ahí
- [x] 7.3 Verificar versiones personalizadas: con `PRODUCTS_APP_VERSION=2.0.0` `/api/products/health` devuelve `"version":"2.0.0"`; luego `docker compose down` y eliminar el `.env` de prueba si se creó solo para esta verificación, dejando los volúmenes limpios con `down -v`

## 8. Documentación y cierre

- [x] 8.1 Escribir `frontend/README.md` en español (estructura, comandos de desarrollo, pruebas, lint, build, nginx y variable `APP_VERSION`) y actualizar el `README.md` raíz con `docker compose` y `cp .env.example .env`; verificar que los comandos documentados corren tal cual
- [x] 8.2 Hacer que `./init.sh` ejecute también las pruebas del frontend (ya detecta `frontend/package.json`) y confirmar que termina con código 0; actualizar `AGENTS.md` solo si cambia la estructura
- [x] 8.3 Ejecutar `openspec validate frontend-angular` y revisar nombres de archivos e identificadores en inglés, y textos visibles, comentarios y mensajes en español
- [x] 8.4 Cerrar el change: `feature_list.json` con `frontend-angular` en `done` y `evidence` (tests, lint, build, docker, curl) y nueva sección en `progress.md` con siguiente paso `infra-aws-terraform`; verificar que `infra-aws-terraform` queda `pending`

## Workflow follow-up

- Archivar con `/openspec-archive-change` tras la revisión del humano.
- No hacer commit ni `git push` sin confirmación.
