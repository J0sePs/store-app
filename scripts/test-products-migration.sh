#!/usr/bin/env bash
# Prueba la migración de la columna "category" de products-service contra PostgreSQL real.
#
# Escenario (el mismo que en AWS): la tabla la creó la versión anterior, sin la columna y con datos.
#   1. la versión anterior (construida desde un commit de git) crea la tabla y se le añaden productos;
#   2. la versión nueva (árbol de trabajo) arranca contra esa misma base y migra;
#   3. la versión nueva se reinicia (idempotencia);
#   4. la versión anterior vuelve a arrancar sobre la base ya migrada (compatibilidad hacia atrás).
#
# Uso:  bash scripts/test-products-migration.sh [commit-de-la-version-anterior]   (por defecto 0688166)
# Necesita docker y git. Usa contenedores, red y volumen temporales con contraseña aleatoria (no se muestra).
# Códigos de salida: 0 = todo correcto, 1 = alguna comprobación falló, 2 = error de entrada.

# shellcheck disable=SC2016,SC2034 # las condiciones de check() se evalúan con eval, por eso van entre comillas simples
set -u
V1_COMMIT="${1:-0688166}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$V1_COMMIT" =~ ^[0-9a-f]{7,40}$ ]] || { echo "Commit no válido: $V1_COMMIT" >&2; exit 2; }
git -C "$ROOT" cat-file -e "$V1_COMMIT^{commit}" 2> /dev/null || { echo "No existe el commit $V1_COMMIT" >&2; exit 2; }

N="migcheck-$$"
PASSWORD="$(python3 -c 'import secrets; print(secrets.token_hex(12))')"
WORK="$(mktemp -d)"
pass=0
fail=0

cleanup() {
  docker rm -f "$N-v1" "$N-v2" "$N-v1b" "$N-db" > /dev/null 2>&1
  docker network rm "$N" > /dev/null 2>&1
  docker volume rm "$N-data" > /dev/null 2>&1
  docker rmi "products-service:$N-v1" "products-service:$N-v2" > /dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

ok() { echo "  OK    $*"; pass=$((pass + 1)); }
bad() { echo "  FALLA $*"; fail=$((fail + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

q() { docker exec -e PGPASSWORD="$PASSWORD" "$N-db" psql -h 127.0.0.1 -U products -d products -tAc "$1"; }
api() { docker run --rm --network "$N" curlimages/curl:8.11.1 -s "$@"; }
code() { docker run --rm --network "$N" curlimages/curl:8.11.1 -s -o /dev/null -w '%{http_code}' "$@"; }
rows_hash() { q "select id,name,price,stock,created_at from products order by id" | md5sum | cut -c1-12; }
columns() { q "select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns where table_name='products'"; }

start() { # start <nombre> <imagen>
  docker run -d --name "$N-$1" --network "$N" -e DATABASE_URL="postgresql+psycopg://products:$PASSWORD@$N-db:5432/products" \
    -e APP_VERSION="$1" "$2" > /dev/null
  for _ in $(seq 1 40); do
    [ "$(code "http://$N-$1:8000/health")" = "200" ] && return 0
    sleep 1
  done
  echo "No arrancó $1"
  docker logs "$N-$1" 2>&1 | tail -5
  return 1
}

echo "== Preparación: imagen de la versión anterior ($V1_COMMIT) y de la nueva (árbol de trabajo)"
git -C "$ROOT" archive "$V1_COMMIT" products-service | tar -x -C "$WORK"
docker build -q -t "products-service:$N-v1" "$WORK/products-service" > /dev/null || exit 2
docker build -q -t "products-service:$N-v2" "$ROOT/products-service" > /dev/null || exit 2
check "la versión anterior no conoce category" '! grep -q category "$WORK/products-service/app/models/product.py"'

docker network create "$N" > /dev/null
docker volume create "$N-data" > /dev/null
docker run -d --name "$N-db" --network "$N" -v "$N-data:/var/lib/postgresql/data" -e POSTGRES_PASSWORD="$PASSWORD" \
  -e POSTGRES_USER=products -e POSTGRES_DB=products postgres:16-alpine > /dev/null
for _ in $(seq 1 40); do docker exec "$N-db" pg_isready -U products -d products > /dev/null 2>&1 && break; sleep 1; done

echo "== 1) La versión anterior crea la tabla sin category y se añaden productos"
start v1 "products-service:$N-v1" || exit 1
for datos in '{"name":"Webcam","price":39.9,"stock":7}' '{"name":"Cable HDMI","price":5.5,"stock":40}'; do
  api -X POST -H 'Content-Type: application/json' -d "$datos" "http://$N-v1:8000/products" > /dev/null
done
docker stop "$N-v1" > /dev/null
BEFORE="$(rows_hash)"
check "la tabla no tiene la columna category" '[ "$(columns)" = "id,name,price,stock,created_at" ]'
check "hay 5 filas (3 sembradas y 2 creadas)" '[ "$(q "select count(*) from products")" = "5" ]'

echo "== 2) La versión nueva arranca contra esa misma base"
start v2 "products-service:$N-v2" || exit 1
check "el log indica que se aplicó la migración" 'docker logs "$N-v2" 2>&1 | grep -q "Migración aplicada"'
check "la columna category existe" '[ "$(columns)" = "id,name,price,stock,created_at,category" ]'
check "category es NOT NULL con valor por defecto General" \
  '[ "$(q "select is_nullable||column_default from information_schema.columns where table_name='"'"'products'"'"' and column_name='"'"'category'"'"'")" = "NO'"'"'General'"'"'::character varying" ]'
check "los 5 productos existentes tienen General" '[ "$(q "select count(*) from products where category = '"'"'General'"'"'")" = "5" ]'
check "los datos existentes no cambiaron" '[ "$(rows_hash)" = "$BEFORE" ]'
check "GET /products devuelve category en todas las filas" \
  'api "http://$N-v2:8000/products" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if len(d)==5 and all(\"category\" in p for p in d) else 1)"'

echo "== 3) Idempotencia: la versión nueva se reinicia"
docker restart "$N-v2" > /dev/null
for _ in $(seq 1 40); do [ "$(code "http://$N-v2:8000/health")" = "200" ] && break; sleep 1; done
check "el log indica que la columna ya existe" 'docker logs "$N-v2" 2>&1 | grep -q "la columna ya existe"'
check "sin cambios en los datos ni duplicados" '[ "$(rows_hash)" = "$BEFORE" ] && [ "$(q "select count(*) from products")" = "5" ]'
check "alta con categoría" \
  '[ "$(code -X POST -H "Content-Type: application/json" -d "{\"name\":\"Silla\",\"price\":80,\"stock\":3,\"category\":\"Muebles\"}" "http://$N-v2:8000/products")" = "201" ]'
docker stop "$N-v2" > /dev/null

echo "== 4) La versión anterior vuelve a arrancar sobre la base ya migrada"
start v1b "products-service:$N-v1" || exit 1
check "la versión anterior lista los productos (200)" '[ "$(code "http://$N-v1b:8000/products")" = "200" ]'
check "la versión anterior crea un producto (201)" \
  '[ "$(code -X POST -H "Content-Type: application/json" -d "{\"name\":\"Creado por la v1\",\"price\":9.9,\"stock\":1}" "http://$N-v1b:8000/products")" = "201" ]'
check "el producto creado por la versión anterior recibe General" \
  '[ "$(q "select category from products where name = '"'"'Creado por la v1'"'"'")" = "General" ]'
check "sin errores en los logs de la versión anterior" '[ "$(docker logs "$N-v1b" 2>&1 | grep -ciE "error|traceback")" = "0" ]'

echo
echo "RESULTADO: $pass correctas, $fail fallidas"
[ "$fail" -eq 0 ]
