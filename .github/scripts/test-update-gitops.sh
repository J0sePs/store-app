#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034 # las condiciones de check() se evalúan con eval, por eso van entre comillas simples
# Prueba local de update-gitops.sh contra un remoto git temporal (no toca ningún remoto real).
#
# Uso: bash .github/scripts/test-update-gitops.sh <directorio-de-trabajo> <ruta-a-kustomize> <ruta-a-store-gitops>
#   p. ej.: bash .github/scripts/test-update-gitops.sh "$(mktemp -d)" "$(command -v kustomize)" ../store-gitops
# El directorio de trabajo se vacía antes de empezar. Necesita git, python3 y kustomize.
set -uo pipefail
[ "$#" -eq 3 ] || { echo "Uso: $0 <directorio-de-trabajo> <ruta-a-kustomize> <ruta-a-store-gitops>" >&2; exit 2; }
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/update-gitops.sh"
SRC="$(cd "$3" && pwd)"
W="$1"
case "$W" in /|"") echo "Directorio de trabajo no válido" >&2; exit 2;; esac
rm -rf "$W"; mkdir -p "$W"; W="$(cd "$W" && pwd)"; cd "$W" || exit 1
export KUSTOMIZE_BIN="$2" RETRY_SLEEP_BASE=0 MAX_ATTEMPTS=3 ECR_REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com GIT_TERMINAL_PROMPT=0
pass=0; failn=0
ok()  { echo "  OK    $*"; pass=$((pass+1)); }
bad() { echo "  FALLA $*"; failn=$((failn+1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

git clone -q --bare "$SRC" remote.git
git --git-dir=remote.git symbolic-ref HEAD refs/heads/main
newclone() { git clone -q remote.git "$1" 2>/dev/null; git -C "$1" config user.name tester; git -C "$1" config user.email t@example.com; }
run() { local dir=$1 comp=$2 sha=$3; COMPONENT=$comp SHORT_SHA=$sha GITOPS_DIR=$dir bash "$SCRIPT" > "$W/out.txt" 2>&1; echo $? > "$W/rc.txt"; }
rc() { cat "$W/rc.txt"; }
remote_head() { git --git-dir=remote.git rev-parse main; }
remote_msg() { git --git-dir=remote.git log -1 --format=%s main; }
remote_file() { git --git-dir=remote.git show "main:$1"; }

echo "== 1. Caso feliz (frontend abc1234)"
newclone a; before=$(remote_head)
run a frontend abc1234
check "código de salida 0" '[ "$(rc)" = 0 ]'
check "commit 'deploy(frontend): abc1234' en el remoto" '[ "$(remote_msg)" = "deploy(frontend): abc1234" ]'
check "autor github-actions[bot]" '[ "$(git --git-dir=remote.git log -1 --format=%an main)" = "github-actions[bot]" ]'
check "solo cambió apps/frontend/kustomization.yaml" '[ "$(git --git-dir=remote.git diff --name-only $before main)" = "apps/frontend/kustomization.yaml" ]'
check "newTag abc1234 y newName del ECR" 'remote_file apps/frontend/kustomization.yaml | grep -q "newTag: abc1234" && remote_file apps/frontend/kustomization.yaml | grep -q "newName: 123456789012.dkr.ecr.us-east-1.amazonaws.com/frontend"'
rm -rf chk && git clone -q remote.git chk && built=$(cd chk/apps/frontend && "$KUSTOMIZE_BIN" build .)
check "kustomize build: APP_VERSION y tag = abc1234" 'grep -A1 "name: APP_VERSION" <<< "$built" | grep -q abc1234 && grep -q "frontend:abc1234" <<< "$built"'
check "mensajes en español" 'grep -q "Subido a main" "$W/out.txt"'

echo "== 2. Remoto adelantado, otro componente (rebase limpio)"
newclone stale; newclone other
COMPONENT=products-service SHORT_SHA=1111111 GITOPS_DIR=other bash "$SCRIPT" > /dev/null 2>&1
run stale orders-service 2222222
check "código de salida 0" '[ "$(rc)" = 0 ]'
check "el remoto conserva el commit ajeno" 'git --git-dir=remote.git log --format=%s main | grep -q "deploy(products-service): 1111111"'
check "el remoto tiene el commit nuevo" 'git --git-dir=remote.git log --format=%s main | grep -q "deploy(orders-service): 2222222"'
check "historia lineal (sin merges)" '[ -z "$(git --git-dir=remote.git log --merges --format=%h main)" ]'

echo "== 3. Conflicto en el mismo kustomization.yaml"
newclone stale2; newclone other2
COMPONENT=frontend SHORT_SHA=3333333 GITOPS_DIR=other2 bash "$SCRIPT" > /dev/null 2>&1
run stale2 frontend 4444444
check "código de salida 0" '[ "$(rc)" = 0 ]'
check "se detectó el conflicto y se repitió desde el remoto" 'grep -q "tuvo conflicto" "$W/out.txt"'
check "el frontend termina con el SHA del script (4444444)" 'remote_file apps/frontend/kustomization.yaml | grep -Eq "newTag: \"?4444444\"?"'
check "se conserva el commit ajeno (3333333)" 'git --git-dir=remote.git log --format=%s main | grep -q "deploy(frontend): 3333333"'
check "copia de trabajo limpia (sin rebase a medias)" '[ -z "$(git -C stale2 status --porcelain)" ] && [ ! -d stale2/.git/rebase-merge ]'

echo "== 4a. Sin cambios (copia al día, mismo SHA otra vez; es el caso real de la CI)"
newclone fresh; head1=$(remote_head); run fresh frontend 4444444
check "código de salida 0" '[ "$(rc)" = 0 ]'
check "mensaje 'Sin cambios'" 'grep -q "Sin cambios" "$W/out.txt"'
check "el remoto no cambió" '[ "$(remote_head)" = "$head1" ]'
echo "== 4b. Copia atrasada cuyo cambio ya está en el remoto"
head1=$(remote_head); run a frontend 4444444
check "código de salida 0" '[ "$(rc)" = 0 ]'
check "mensaje 'El remoto ya contiene este cambio' (no dice Subido)" 'grep -q "El remoto ya contiene este cambio" "$W/out.txt" && ! grep -q "Subido a" "$W/out.txt"'
check "el remoto no cambió" '[ "$(remote_head)" = "$head1" ]'

echo "== 5. APP_VERSION que no coincide (falla antes del commit)"
newclone bad; head1=$(remote_head)
python3 - bad/apps/products-service/kustomization.yaml <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
s=s.split("replacements:")[0]   # se elimina el bloque replacements: APP_VERSION ya no sigue al tag
open(p,"w").write(s)
PY
git -C bad commit -qam "romper replacements (solo local)"
run bad products-service 5555555
check "código de salida 1" '[ "$(rc)" = 1 ]'
check "mensaje de error de APP_VERSION" 'grep -q "APP_VERSION vale" "$W/out.txt"'
check "no se creó commit de deploy ni se subió nada" '[ "$(remote_head)" = "$head1" ] && ! git -C bad log --format=%s | grep -q "deploy(products-service): 5555555"'

echo "== 6. Push rechazado una vez y luego aceptado (reintento)"
newclone retry; head1=$(remote_head)
cat > remote.git/hooks/pre-receive <<'HOOK'
#!/usr/bin/env bash
# Rechaza el primer push y acepta los siguientes
c="$(dirname "$0")/../rejects"; n=$(cat "$c" 2>/dev/null || echo 0)
if [ "$n" -lt 1 ]; then echo $((n+1)) > "$c"; echo "rechazado por la prueba" >&2; exit 1; fi
HOOK
chmod +x remote.git/hooks/pre-receive; rm -f remote.git/rejects
run retry orders-service 6666666
check "código de salida 0" '[ "$(rc)" = 0 ]'
check "hubo un rechazo y un reintento" 'grep -q "rechazado (intento 1 de 3)" "$W/out.txt"'
check "el remoto recibió el commit" '[ "$(remote_msg)" = "deploy(orders-service): 6666666" ]'

echo "== 7. Reintentos agotados (el remoto rechaza siempre)"
newclone fail; head1=$(remote_head)
printf '#!/usr/bin/env bash\necho "rechazado por la prueba" >&2\nexit 1\n' > remote.git/hooks/pre-receive
run fail frontend 7777777
check "código de salida 1" '[ "$(rc)" = 1 ]'
check "mensaje en español tras 3 intentos" 'grep -q "No se pudo hacer push a main tras 3 intentos" "$W/out.txt"'
check "el remoto no cambió" '[ "$(remote_head)" = "$head1" ]'
rm -f remote.git/hooks/pre-receive

echo "== 8. Entradas inválidas"
newclone inv
COMPONENT=frontend SHORT_SHA=ABC GITOPS_DIR=inv bash "$SCRIPT" > /dev/null 2>&1; r1=$?
COMPONENT='frontend; touch pwned' SHORT_SHA=abc1234 GITOPS_DIR=inv bash "$SCRIPT" > /dev/null 2>&1; r2=$?
COMPONENT=frontend SHORT_SHA=abc1234 ECR_REGISTRY='evil.com/x' GITOPS_DIR=inv bash "$SCRIPT" > /dev/null 2>&1; r3=$?
env -u COMPONENT SHORT_SHA=abc1234 GITOPS_DIR=inv bash "$SCRIPT" > /dev/null 2>&1; r4=$?
check "SHA inválido -> 2" '[ $r1 = 2 ]'
check "componente con inyección -> 2 y sin efectos" '[ $r2 = 2 ] && [ ! -e inv/pwned ] && [ ! -e pwned ]'
check "registro inválido -> 2" '[ $r3 = 2 ]'
check "falta COMPONENT -> error" '[ $r4 != 0 ]'

echo; echo "RESULTADO: $pass correctas, $failn fallidas"
[ "$failn" = 0 ]
