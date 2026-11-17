# Tasks

## 1. Estado y andamiaje

- [x] 1.1 Marcar `orders-service-go` como `in_progress` en `feature_list.json`; verificar con `./init.sh` que solo hay un change activo
- [x] 1.2 Crear `orders-service/` con `go.mod` (módulo `orders-service`, `go 1.25`), dependencias `chi/v5` y `pgx/v5`, `cmd/server/`, `internal/{config,handler,model,repository}` y `.dockerignore`; verificar con `go mod tidy` y `go build ./...` sin errores
- [x] 1.3 Verificar que los binarios compilados (`orders-service/bin/`) quedan ignorados con `git check-ignore orders-service/bin/server`

## 2. Configuración y modelo

- [x] 2.1 Implementar `internal/config` (`DATABASE_URL` obligatoria con error en español, `APP_VERSION` por defecto `dev`); verificar con tests: variable definida, ausente y versión por defecto
- [x] 2.2 Implementar `internal/model` (`Order` con etiquetas JSON `id`, `product_id`, `quantity`, `customer`, `status`, `created_at` y `CreateOrderInput` sin campo `status`) y la validación de entrada; verificar con tests de tabla: `product_id` 0 o negativo, `quantity` 0, `customer` vacío o con solo espacios, entrada válida

## 3. Repositorio y migración

- [x] 3.1 Implementar la migración SQL embebida (`CREATE TABLE IF NOT EXISTS orders`, sin clave foránea) y su ejecución al arrancar; verificar que `go vet ./...` pasa y que el SQL contiene `CREATE TABLE IF NOT EXISTS`
- [x] 3.2 Implementar `internal/repository` con `pgxpool` (`List` ordenado por `id`, `Get` con `ErrNotFound`, `Create` con `RETURNING`), errores envueltos con `%w`; verificar con `go build ./...` y, más adelante, con la prueba contra PostgreSQL de la tarea 5.2

## 4. API y arranque

- [x] 4.1 Implementar `internal/handler` con chi: `GET /orders` (siempre `[]`, nunca `null`), `GET /orders/{id}` (404 `Pedido no encontrado`, 400 `Identificador inválido`), `POST /orders` (201, `status` `pending`, 400 con mensajes en español), `GET /health`, y la interfaz `OrderStore`; verificar con tests `httptest` y un fake en memoria que cubren todos los escenarios del spec
- [x] 4.2 Verificar en tests que un `status` enviado por el cliente se ignora, que un JSON mal formado devuelve 400 y que un error del repositorio devuelve 500 `Error interno del servidor` sin filtrar detalles
- [x] 4.3 Implementar `cmd/server/main.go`: configuración, `pgxpool` con reintento (5 intentos, 2 s), migración, servidor en el puerto 8080 con timeouts y apagado ordenado, logs en español con `slog`, salida con código 1 si falta `DATABASE_URL`; verificar con `go build ./cmd/server` y ejecutando el binario sin `DATABASE_URL` (mensaje en español y código 1)
- [x] 4.4 Ejecutar `gofmt -l .`, `go vet ./...` y `go test ./...` en `orders-service/`; verificar que no hay archivos sin formatear ni errores y que todos los escenarios de la API del spec tienen un test

## 5. Contenedor y verificación con PostgreSQL

- [x] 5.1 Crear el `Dockerfile` multi-stage (build `golang:1.25-alpine`, final `gcr.io/distroless/static-debian12:nonroot`, `EXPOSE 8080`); verificar con `docker build -t orders-service:dev orders-service/` y que `docker image inspect` muestra un usuario distinto de root y de vacío, y que `docker run --rm --entrypoint sh orders-service:dev` falla por no haber shell
- [x] 5.2 Probar contra PostgreSQL real: red Docker temporal, contenedor `postgres:16-alpine` con credenciales de prueba por variable de entorno (no se guardan en git) y el servicio; verificar con un contenedor `curl` en la misma red que `/health`, `GET /orders` (`[]`), `POST /orders` (201, `pending`), `GET /orders/1`, `GET /orders/9999` (404) y `POST` inválido (400) responden como en los specs, y que tras reiniciar el servicio el pedido sigue ahí; limpiar contenedores y red al terminar

## 6. Documentación y cierre

- [x] 6.1 Escribir `orders-service/README.md` en español (variables de entorno, endpoints con ejemplos `curl`, formato de error `{"error": ...}`, nota de que `product_id` no se valida, cómo correr tests, `gofmt`/`go vet`, `docker build/run`); verificar que los comandos documentados corren tal cual
- [x] 6.2 Confirmar con `./init.sh` que ahora ejecuta `go test ./...` de `orders-service` junto con `pytest` de `products-service` y termina con código 0; actualizar la estructura de `AGENTS.md` solo si cambia algo
- [x] 6.3 Ejecutar `openspec validate orders-service-go` y verificar nombres de archivos e identificadores en inglés y comentarios, logs y errores en español (revisión manual)
- [x] 6.4 Cerrar el change: `feature_list.json` con `orders-service-go` en `done` y `evidence` (tests, `go vet`, `docker`, `curl`), y nueva sección en `progress.md` con siguiente paso `frontend-angular`; verificar que `frontend-angular` queda `pending`

## Workflow follow-up

- Archivar con `/openspec-archive-change` tras la revisión del humano.
- No hacer commit ni `git push` sin confirmación.
