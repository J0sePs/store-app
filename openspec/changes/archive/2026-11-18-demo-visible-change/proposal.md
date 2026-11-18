## Why

La v1 ya corre en AWS (imágenes con el SHA `0688166`, Argo CD `Synced/Healthy`). Falta el último change: un cambio pequeño y **visible** para grabar el video de la demo de GitOps (push → GitHub Actions → ECR → commit en `store-gitops` → Argo CD → rolling update). El cambio debe notarse a simple vista en el navegador y, a la vez, tocar el backend con una migración real, porque la tabla `products` ya existe en AWS con datos y `create_all` no añade columnas a una tabla existente.

## What Changes

- **Frontend (Angular):** banner con el texto "Versión 2 - desplegada con GitOps" en el hueco `.banner-slot` del shell, visible en todas las vistas. La tabla de productos gana una columna con el encabezado "Categoría" y el formulario un campo opcional "Categoría".
- **`products-service` (FastAPI):** campo `category` en el modelo `Product` (texto de 1 a 100 caracteres, por defecto `General`), expuesto en `GET /products`, `GET /products/{id}` y aceptado de forma opcional en `POST /products`.
- **Migración al arrancar, idempotente:** `ALTER TABLE products ADD COLUMN IF NOT EXISTS category VARCHAR(100) NOT NULL DEFAULT 'General'` en PostgreSQL. Los productos existentes reciben `General` sin perder datos. En SQLite (solo en tests) se comprueba la columna antes de añadirla, porque SQLite no admite `IF NOT EXISTS` en `ADD COLUMN`.
- **Compatibilidad hacia atrás:** la columna tiene valor por defecto, así que la versión anterior del servicio sigue funcionando contra la base ya migrada (importa durante el rolling update y para un rollback).
- **Pruebas:** tests actualizados y nuevos (API y migración), y una prueba en local con **PostgreSQL real**: se crea la tabla con el código v1 (sin la columna), se arranca la v2 y se comprueba la migración, su idempotencia y el retorno a v1.
- READMEs de `products-service` y `frontend`.

Al terminar: validar, archivar y proponer el mensaje de commit. **No se hace `git push`**: lo hará el usuario mientras graba el video.

Supuestos (ver design): los productos existentes mostrarán `General`; el campo del formulario es opcional; no se añade Alembic.

No hay cambios **BREAKING**.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `products-catalog`: campo `category` en listado, detalle y alta, y migración idempotente al arrancar.
- `store-frontend`: columna y campo "Categoría" en la vista de productos, y banner de versión en todas las vistas.

## Impact

- **Componentes afectados:** `products-service/` y `frontend/` (código, tests y README). `store-gitops` no cambia a mano: la CI lo actualizará con los dos nuevos tags al hacer push.
- **Despliegue:** el push toca `frontend/` y `products-service/`, así que correrán dos workflows en paralelo; sus `update-gitops` se serializan. La migración corre en el pod nuevo de `products-service` contra la base de AWS, mientras el pod viejo sigue sirviendo.
- **Capacidad:** sin cambios en pods ni memoria (`scripts/check-capacity.py` sigue en 17 de 22 pods).
- **Fuera de alcance:** Alembic u otro sistema de migraciones, categorías como entidad propia, edición de productos y rellenar categorías de los productos existentes.
