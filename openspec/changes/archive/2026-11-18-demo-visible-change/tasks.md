# Tasks

> Reglas: **no se hace `git push`** (lo hará el usuario grabando el video) ni se toca `store-gitops` a mano ni el clúster. Los commits los hace el usuario; al terminar se propone el mensaje. Las pruebas con PostgreSQL usan contenedores locales temporales, con contraseñas aleatorias que no se muestran ni se guardan.

## 1. Estado

- [x] 1.1 Marcar `demo-visible-change` (`change-7`) como `in_progress` en `feature_list.json`; verificar con `./init.sh` que solo hay un change activo

## 2. products-service: `category` y migración

- [x] 2.1 Añadir `category` (`String(100)`, `nullable=False`, `server_default="General"`) al modelo y a los esquemas (`ProductCreate` opcional y recortada, de 1 a 100 caracteres; `ProductRead` obligatoria), con categorías en la siembra de instalaciones nuevas; verificar con los tests de API y de siembra actualizados (listado, detalle, alta con y sin categoría y categoría inválida → 422)
- [x] 2.2 Escribir `app/db/migrations.py` (`ensure_category_column`: `ALTER TABLE ... ADD COLUMN IF NOT EXISTS ... DEFAULT 'General'` en PostgreSQL; inspector y `ALTER` en SQLite) y llamarla desde `init_db` tras `create_all`, con logs en español; verificar con tests de migración sobre una tabla creada con el DDL de la v1 y con filas: columna añadida, filas existentes en `General` y datos intactos, segunda ejecución sin cambios y sin duplicar la siembra
- [x] 2.3 Ejecutar `ruff check .`, `ruff format --check .` y `pytest` en `products-service/`; verificar que terminan sin errores y que cada escenario nuevo del spec `products-catalog` tiene un test

## 3. Prueba de la migración contra PostgreSQL real

- [x] 3.1 Construir la imagen **v1** desde el commit `0688166` con `git archive` en un directorio temporal, y la imagen **v2** desde el árbol de trabajo; verificar con `docker image ls` que existen las dos
- [x] 3.2 Crear la situación de AWS: PostgreSQL 16 temporal y la v1 contra él (crea la tabla sin `category` y siembra), crear un par de productos más por la API y detener la v1; verificar con `psql` que la tabla **no** tiene la columna `category` y que tiene 5 filas
- [x] 3.3 Arrancar la v2 contra esa misma base; verificar que los logs en español indican la migración, que la columna existe (`NOT NULL`, valor por defecto `General`), que las 5 filas conservan sus datos, que todas tienen `General` y que `GET /products` devuelve `category`
- [x] 3.4 Probar idempotencia y compatibilidad: reiniciar la v2 (sin errores, sin cambios, sin duplicar) y arrancar de nuevo la v1 contra la base migrada (lee y crea productos sin errores y el producto nuevo recibe `General`); limpiar contenedores, red y volumen al terminar

## 4. Frontend

- [x] 4.1 Añadir `category` (opcional) a las interfaces, la columna "Categoría" tras "Nombre" (con `—` si falta) y el campo opcional "Categoría" del formulario (se omite del cuerpo si está vacío); verificar con tests de `products-page`: encabezados, celda sin categoría, alta con categoría y alta sin ella
- [x] 4.2 Crear `shared/release-banner` con el texto "Versión 2 - desplegada con GitOps" (`role="status"`), mostrarlo en el `.banner-slot` del shell y darle estilo con las variables CSS; verificar con tests del componente y del shell (visible en `/products` y en `/orders`, junto al pie de versiones)
- [x] 4.3 Ejecutar `npm run lint`, `npm test -- --watch=false` y `npm run build` en `frontend/`; verificar que terminan sin errores

## 5. Integración local

- [x] 5.1 Levantar todo con `docker compose` (v2 local) en un puerto alterno y comprobar con `curl` que `/api/products` devuelve `category`, que se puede crear un producto con y sin categoría y que el frontend responde; verificar además con Chromium headless una captura de `/products` con el banner y la columna "Categoría", y dejar el stack local como estaba antes (recreado limpio en el puerto 80)

## 6. Documentación y cierre

- [x] 6.1 Actualizar `products-service/README.md` (campo `category`, validación y migración idempotente al arrancar, con el comando de prueba contra PostgreSQL) y `frontend/README.md` (banner y columna); verificar que los comandos documentados corren tal cual
- [x] 6.2 Ejecutar `scripts/check-capacity.py`, `./init.sh` y `openspec validate demo-visible-change`; verificar que la capacidad sigue en 17 de 22 pods y que todo termina sin errores
- [x] 6.3 Comprobar el contenido del futuro commit: lista de archivos por componente (qué workflows disparará el push: `frontend.yml` y `products-service.yml`) y búsqueda de datos sensibles; verificar que no hay secretos, cuenta de AWS ni tokens
- [x] 6.4 Sincronizar los specs y archivar el change (`products-catalog` y `store-frontend` modificados), actualizar `feature_list.json` y `progress.md`, y proponer el mensaje de commit; verificar con `openspec validate --specs` y que `git status` no muestra archivos ignorados. **No se hace commit ni push.**

## Workflow follow-up

- El usuario hace el commit y el `git push origin main` mientras graba el video: se lanzarán `frontend.yml` y `products-service.yml`.
- Comprobación de la demo: ECR con los 2 tags nuevos, 2 commits `deploy(...)` en `store-gitops`, Argo CD `Synced/Healthy`, banner, columna "Categoría" y versiones nuevas en el pie.
