#!/usr/bin/env bash
# Verifica el entorno de desarrollo y corre los tests de los componentes existentes.
# Solo lectura: no ejecuta terraform apply/destroy, git push, kubectl apply ni aws que modifique recursos.
# Uso: ./init.sh   (SKIP_TESTS=1 ./init.sh para omitir los tests)

# Sin "set -e": se revisan todas las herramientas aunque alguna falte.
cd "$(dirname "$0")" || exit 1

missing=()
failed=()

echo "=== Herramientas ==="
check_tool() {
  local name="$1"; shift
  if command -v "$name" >/dev/null 2>&1; then
    local version
    version="$("$@" 2>&1 | head -n 1)"
    printf '  [ok]    %-10s %s\n' "$name" "$version"
  else
    printf '  [falta] %-10s no está instalado\n' "$name"
    missing+=("$name")
  fi
}

check_tool git git --version
check_tool docker docker --version
check_tool node node --version
check_tool python3 python3 --version
check_tool go go version
check_tool terraform terraform version
check_tool aws aws --version
check_tool kubectl kubectl version --client
check_tool openspec openspec --version

echo
echo "=== feature_list.json ==="
if [ ! -f feature_list.json ]; then
  echo "  [aviso] feature_list.json no existe"
elif command -v python3 >/dev/null 2>&1; then
  if python3 - <<'PY'
import json, sys
try:
    features = json.load(open("feature_list.json"))["features"]
except Exception as exc:
    print(f"  [error] JSON inválido: {exc}")
    sys.exit(1)
required = {"id", "name", "description", "status", "evidence"}
valid = {"pending", "in_progress", "done"}
bad = False
for f in features:
    if not required <= set(f) or f["status"] not in valid:
        print(f"  [error] entrada inválida: {f.get('id', '?')}")
        bad = True
    elif f["status"] == "done" and not f["evidence"]:
        print(f"  [error] {f['id']} está done sin evidence")
        bad = True
active = [f["name"] for f in features if f["status"] == "in_progress"]
if len(active) > 1:
    print(f"  [aviso] más de un change in_progress: {', '.join(active)}")
done = sum(f["status"] == "done" for f in features)
print(f"  [ok]    {len(features)} changes, {done} done, activo: {', '.join(active) or 'ninguno'}")
sys.exit(1 if bad else 0)
PY
  then :; else failed+=("feature_list.json"); fi
else
  echo "  [aviso] sin python3: no se valida feature_list.json"
fi

echo
echo "=== Tests de componentes ==="
# run_tests <nombre> <carpeta> <archivo-que-prueba-existencia> <herramienta> <comando...>
run_tests() {
  local name="$1" dir="$2" marker="$3" tool="$4"; shift 4
  if [ ! -f "$dir/$marker" ]; then
    echo "  [omitido] $name: aún no existe ($dir/$marker)"
    return
  fi
  if [ "${SKIP_TESTS:-0}" = "1" ]; then
    echo "  [omitido] $name: SKIP_TESTS=1"
    return
  fi
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "  [omitido] $name: falta $tool"
    return
  fi
  echo "  -> $name: $*"
  if (cd "$dir" && "$@"); then
    echo "  [ok]    $name"
  else
    echo "  [fallo] $name"
    failed+=("$name")
  fi
}

# products-service usa su venv local si existe (ahí están pytest y las dependencias)
PRODUCTS_PY="python3"
[ -x products-service/.venv/bin/python ] && PRODUCTS_PY="$PWD/products-service/.venv/bin/python"
run_tests products-service products-service requirements.txt python3 "$PRODUCTS_PY" -m pytest -q
run_tests orders-service orders-service go.mod go go test ./...
run_tests frontend frontend package.json npm npm test -- --watch=false

echo
echo "=== Resumen ==="
if [ "${#missing[@]}" -gt 0 ]; then
  echo "  Herramientas que faltan: ${missing[*]}"
else
  echo "  Todas las herramientas están instaladas."
fi
if [ "${#failed[@]}" -gt 0 ]; then
  echo "  Fallos: ${failed[*]}"
  exit 1
fi
echo "  Sin fallos."
echo
echo "Siguiente: lee progress.md y feature_list.json; trabaja UN change a la vez."
exit 0
