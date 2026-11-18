#!/usr/bin/env bash
# Actualiza la imagen de un componente en el repositorio store-gitops y la sube a main.
#
# Pasos: kustomize edit set image -> comprobar APP_VERSION -> commit -> pull --rebase + push con reintentos.
# Todo llega por variables de entorno (el workflow no interpola datos dentro del shell).
#
# Variables obligatorias:
#   COMPONENT     frontend | products-service | orders-service
#   ECR_REGISTRY  <cuenta>.dkr.ecr.<región>.amazonaws.com
#   SHORT_SHA     7 primeros caracteres del SHA del commit
#   GITOPS_DIR    copia de trabajo de store-gitops (ya clonada y autenticada)
# Variables opcionales:
#   GITOPS_BRANCH (main), MAX_ATTEMPTS (5), RETRY_SLEEP_BASE (3 s), KUSTOMIZE_BIN (kustomize)
#
# Códigos de salida: 0 = actualizado o sin cambios, 1 = fallo, 2 = entrada inválida.

set -euo pipefail

log() { echo "[gitops] $*"; }
fail() { echo "[gitops] ERROR: $*" >&2; exit "${2:-1}"; }

: "${COMPONENT:?Falta la variable COMPONENT}"
: "${ECR_REGISTRY:?Falta la variable ECR_REGISTRY}"
: "${SHORT_SHA:?Falta la variable SHORT_SHA}"
: "${GITOPS_DIR:?Falta la variable GITOPS_DIR}"
BRANCH="${GITOPS_BRANCH:-main}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-5}"
RETRY_SLEEP_BASE="${RETRY_SLEEP_BASE:-3}"
KUSTOMIZE_BIN="${KUSTOMIZE_BIN:-kustomize}"

# --- Validación de las entradas (evita inyectar valores raros en comandos o en git) ---
case "$COMPONENT" in
  frontend | products-service | orders-service) ;;
  *) fail "Componente no válido: '$COMPONENT'" 2 ;;
esac
[[ "$SHORT_SHA" =~ ^[0-9a-f]{7}$ ]] || fail "SHORT_SHA debe tener 7 caracteres hexadecimales" 2
[[ "$ECR_REGISTRY" =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com$ ]] || fail "ECR_REGISTRY no tiene el formato <cuenta>.dkr.ecr.<región>.amazonaws.com" 2
[[ "$BRANCH" =~ ^[A-Za-z0-9._/-]+$ ]] || fail "Nombre de rama no válido" 2
[[ "$MAX_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] || fail "MAX_ATTEMPTS debe ser un entero positivo" 2
[[ "$RETRY_SLEEP_BASE" =~ ^[0-9]+$ ]] || fail "RETRY_SLEEP_BASE debe ser un entero" 2
git -C "$GITOPS_DIR" rev-parse --git-dir > /dev/null 2>&1 || fail "GITOPS_DIR no es un repositorio git: $GITOPS_DIR" 2
APP_DIR="$GITOPS_DIR/apps/$COMPONENT"
[ -f "$APP_DIR/kustomization.yaml" ] || fail "No existe $APP_DIR/kustomization.yaml" 2

IMAGE="$ECR_REGISTRY/$COMPONENT:$SHORT_SHA"
MESSAGE="deploy($COMPONENT): $SHORT_SHA"

git_gitops() { git -C "$GITOPS_DIR" "$@"; }

# Identidad del autor de los commits (solo en esta copia de trabajo)
git_gitops config user.name "github-actions[bot]"
git_gitops config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Cambia la imagen y comprueba que APP_VERSION y la imagen quedaron con el SHA nuevo
update_image() {
  log "Actualizando la imagen de $COMPONENT a $IMAGE"
  (cd "$APP_DIR" && "$KUSTOMIZE_BIN" edit set image "$COMPONENT=$IMAGE")

  local built version
  built="$(cd "$APP_DIR" && "$KUSTOMIZE_BIN" build .)" || fail "kustomize build falló tras actualizar la imagen"
  # La imagen del Deployment debe terminar en el tag nuevo
  grep -Eq "^[[:space:]]+image: .*/$COMPONENT:$SHORT_SHA\$" <<< "$built" \
    || fail "La imagen construida no termina en $COMPONENT:$SHORT_SHA"
  # APP_VERSION la copia Kustomize del tag; aquí solo se comprueba que coincide
  version="$(awk '/name: APP_VERSION/ {getline; gsub(/["\047[:space:]]/, ""); sub(/^value:/, ""); print; exit}' <<< "$built")"
  [ "$version" = "$SHORT_SHA" ] || fail "APP_VERSION vale '$version' y debería valer '$SHORT_SHA'; no se hace commit"
  log "Comprobado: APP_VERSION = $SHORT_SHA"
}

# Hace commit si hay cambios. Devuelve 10 si no hay nada que subir.
commit_update() {
  git_gitops add "apps/$COMPONENT/kustomization.yaml"
  if git_gitops diff --cached --quiet; then
    return 10
  fi
  git_gitops commit --quiet -m "$MESSAGE"
  log "Commit creado: $MESSAGE"
}

update_image
if commit_update; then :; else
  rc=$?
  [ "$rc" -eq 10 ] || exit "$rc"
  log "Sin cambios: $COMPONENT ya usa $IMAGE. No hay nada que subir."
  exit 0
fi

attempt=1
while true; do
  # Primero se pone al día con el remoto; si el rebase choca, se empieza de cero desde el remoto
  if git_gitops pull --rebase --quiet origin "$BRANCH"; then
    log "Rama actualizada con pull --rebase (intento $attempt de $MAX_ATTEMPTS)"
  else
    log "El rebase tuvo conflicto; se descarta y se repite la actualización desde origin/$BRANCH"
    git_gitops rebase --abort > /dev/null 2>&1 || true
    git_gitops fetch --quiet origin "$BRANCH"
    git_gitops reset --hard --quiet "origin/$BRANCH"
    update_image
    if commit_update; then :; else
      rc=$?
      [ "$rc" -eq 10 ] || exit "$rc"
      log "Sin cambios tras actualizar desde el remoto: $COMPONENT ya usa $IMAGE."
      exit 0
    fi
  fi

  # Si tras el rebase nuestro commit ya estaba en el remoto, no queda nada que subir
  if [ "$(git_gitops rev-parse HEAD)" = "$(git_gitops rev-parse "origin/$BRANCH")" ]; then
    log "El remoto ya contiene este cambio: $COMPONENT ya usa $IMAGE. No hay nada que subir."
    exit 0
  fi

  if git_gitops push --quiet origin "HEAD:$BRANCH"; then
    log "Subido a $BRANCH: $MESSAGE"
    exit 0
  fi

  if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
    fail "No se pudo hacer push a $BRANCH tras $MAX_ATTEMPTS intentos"
  fi
  log "El push fue rechazado (intento $attempt de $MAX_ATTEMPTS); se reintenta en $((RETRY_SLEEP_BASE * attempt)) s"
  sleep "$((RETRY_SLEEP_BASE * attempt))"
  attempt=$((attempt + 1))
done
