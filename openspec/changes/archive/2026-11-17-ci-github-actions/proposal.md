## Why

El flujo GitOps ya tiene sus dos extremos: la infraestructura (ECR, rol OIDC) y el repositorio `store-gitops` que vigila Argo CD. Falta el eslabón que los une: la CI que, en cada push a `main`, prueba el componente que cambió, publica su imagen en ECR con el SHA corto y le dice a `store-gitops` qué tag desplegar. Sin ella no hay despliegue automático ni demo.

## What Changes

- `.github/workflows/frontend.yml`, `products-service.yml` y `orders-service.yml`: se disparan con un push a `main` que toque la carpeta de su componente (filtro de `paths`) o a mano con `workflow_dispatch`.
- Cada uno: job `test` (tests y lint del componente) → job `build-and-push` → job `update-gitops`.
- `.github/workflows/_deploy-component.yml`: workflow reutilizable con los pasos comunes, para que el código sensible (OIDC, push a ECR, token de gitops) exista una sola vez.
- `build-and-push`: login a AWS por OIDC (`aws-actions/configure-aws-credentials`), login a ECR, build y push con la etiqueta = SHA corto (nunca `latest`), y comprobación de que la imagen quedó en ECR.
- `update-gitops`: solo corre si el push a ECR salió bien. Hace checkout de `<dueño>/store-gitops` con el secret `GITOPS_TOKEN`, ejecuta `kustomize edit set image`, comprueba que `APP_VERSION` pasó a ser el SHA, hace commit `deploy(<servicio>): <sha>` y push con `pull --rebase` y reintentos.
- `.github/scripts/update-gitops.sh`: la lógica de gitops en un script que se puede probar en local.
- Nombres de jobs y steps en inglés, mensajes `echo` en español. README con los secrets y variables que hay que crear.

`APP_VERSION` no necesita un paso propio: en `store-gitops` Kustomize la copia del tag de la imagen. La CI solo verifica que se cumpla.

No hay cambios **BREAKING**.

## Capabilities

### New Capabilities

- `ci-pipeline`: disparo por componente, tests, build y push de imágenes a ECR con autenticación OIDC.
- `ci-gitops-update`: actualización de `store-gitops` tras un push correcto, con verificación de versión y reintentos.
- `ci-secrets-and-docs`: permisos mínimos, secretos y variables requeridos y su documentación.

### Modified Capabilities

Ninguna.

## Impact

- **Componentes afectados:** `.github/` (nuevo) y `README.md` de la raíz.
- **Acciones de terceros:** `actions/checkout`, `setup-node`, `setup-python`, `setup-go`, `aws-actions/configure-aws-credentials` y `amazon-ecr-login`, `docker/setup-buildx-action` y `build-push-action`, con su versión mayor fijada.
- **Fuera de alcance:** ejecutar los workflows (corren en GitHub tras el push), crear los secrets y la infraestructura, despliegues a otros entornos y escaneo de seguridad en CI.
- **Restricciones del proyecto:** sin `latest`, sin `kubectl apply` desde CI y sin llaves de AWS estáticas.
