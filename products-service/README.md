# products-service

Microservicio de productos del proyecto `store-app`. Usa FastAPI y SQLAlchemy con su propia base PostgreSQL (`products-db`); ningún otro servicio accede a ella.

## Variables de entorno

| Variable | Obligatoria | Descripción |
|---|---|---|
| `DATABASE_URL` | Sí | URL de conexión, p. ej. `postgresql+psycopg://usuario:clave@host:5432/products` |
| `APP_VERSION` | No | Versión que devuelve `/health`. Por defecto `dev` |

Si falta `DATABASE_URL`, el servicio termina al arrancar con el mensaje `Falta la variable de entorno DATABASE_URL`.

## Endpoints (puerto 8000)

| Método | Ruta | Respuesta |
|---|---|---|
| GET | `/health` | `200 {"status": "ok", "version": "<APP_VERSION>"}` |
| GET | `/products` | `200` lista ordenada por `id` |
| GET | `/products/{id}` | `200` producto, `404 {"detail": "Producto no encontrado"}`, `422` si el id no es entero |
| POST | `/products` | `201` producto creado, `422` si los datos no son válidos |

Producto: `id`, `name`, `category`, `price`, `stock`, `created_at`. En `POST`, `name` no puede estar vacío, `price` debe ser mayor que 0 y `stock` mayor o igual que 0. `category` es **opcional**: si se envía debe tener de 1 a 100 caracteres (se recortan los espacios; vacía o de solo espacios devuelve 422) y, si se omite, vale `General`.

Al arrancar se crea la tabla `products`, se aplica la migración de `category` y, solo si la tabla está vacía, se siembran 3 productos de ejemplo (en instalaciones nuevas llevan categoría: `Periféricos`, `Periféricos` y `Monitores`).

### Migración de la columna `category`

`create_all` no añade columnas a una tabla que ya existe, así que al arrancar el servicio aplica una migración **idempotente** (`app/db/migrations.py`). En PostgreSQL ejecuta:

```sql
ALTER TABLE products ADD COLUMN IF NOT EXISTS category VARCHAR(100) NOT NULL DEFAULT 'General'
```

- Los productos que ya existían conservan todos sus datos y reciben `General`.
- Es segura si el servicio se reinicia o si dos instancias arrancan a la vez, y con un valor por defecto constante solo modifica metadatos (no reescribe la tabla).
- Como la columna tiene valor por defecto, la **versión anterior del servicio sigue funcionando** contra la base ya migrada (importante durante el rolling update y para un rollback).
- En SQLite (solo en los tests) se comprueba la columna antes de añadirla, porque SQLite no admite `IF NOT EXISTS` en `ADD COLUMN`.

Para probarla contra PostgreSQL real, con una base creada por la versión anterior (necesita Docker; usa contenedores temporales y limpia al terminar):

```bash
bash scripts/test-products-migration.sh            # versión anterior = commit 0688166
bash scripts/test-products-migration.sh c1f527e   # otro commit con la versión anterior (sin category)
```

```bash
curl http://localhost:8000/health
curl http://localhost:8000/products
curl http://localhost:8000/products/1
curl -X POST http://localhost:8000/products \
  -H 'Content-Type: application/json' \
  -d '{"name": "Teclado", "price": 25.5, "stock": 10}'
```

## Desarrollo local

```bash
cd products-service
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
export DATABASE_URL='postgresql+psycopg://usuario:clave@localhost:5432/products'
.venv/bin/uvicorn app.main:app --reload --port 8000
```

## Pruebas y calidad

Las pruebas usan SQLite en memoria; no necesitan PostgreSQL ni Docker.

```bash
.venv/bin/pytest
.venv/bin/ruff check . && .venv/bin/ruff format .
```

## Docker

La imagen es multi-stage y corre con un usuario sin privilegios (uid 10001).

```bash
docker build -t products-service:dev .
docker run --rm -p 8000:8000 \
  -e DATABASE_URL='postgresql+psycopg://usuario:clave@host:5432/products' \
  -e APP_VERSION=0.1.0 \
  products-service:dev
```

Las credenciales reales no se guardan en git: se inyectan por variable de entorno o como Secret de Kubernetes.

## Estructura

```
app/
├── main.py        # aplicación y arranque (crea tabla, migra y siembra)
├── config.py      # variables de entorno
├── api/           # rutas: products, health
├── models/        # modelos SQLAlchemy
├── schemas/       # esquemas Pydantic
└── db/            # base, motor, sesión, migraciones y siembra
tests/
```
