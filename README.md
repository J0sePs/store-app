# store-app

Sistema de microservicios (frontend Angular, `products-service` en FastAPI, `orders-service` en Go) desplegado en AWS EKS con GitOps. Las reglas completas están en `AGENTS.md`.

## Flujo de trabajo para agentes y personas

Cada funcionalidad se hace con un change de OpenSpec (`propose` → revisión → `apply` → `archive`). El estado vive en archivos de la raíz, no en el chat:

| Archivo | Para qué sirve |
|---|---|
| `feature_list.json` | Un registro por change: `id`, `name`, `description`, `status` (`pending` / `in_progress` / `done`) y `evidence`. Solo un change `in_progress` a la vez. |
| `progress.md` | Bitácora en español. Al cerrar un change se agrega qué se hizo, la evidencia y el siguiente paso. |
| `init.sh` | Verifica herramientas y corre los tests de los componentes que existan. |

**Al iniciar sesión:** lee `progress.md` y `feature_list.json`, y ejecuta:

```bash
./init.sh
```

Muestra la versión de `git`, `docker`, `node`, `python3`, `go`, `terraform`, `aws`, `kubectl` y `openspec`, avisa las que falten y corre los tests de `products-service`, `orders-service` y `frontend` si ya existen. Es de solo lectura (no hace `terraform apply`, `git push` ni `kubectl apply`). Con `SKIP_TESTS=1 ./init.sh` se omiten los tests. Sale con código 1 si algún test falla o si `feature_list.json` es inválido.

**Al cerrar un change:** actualiza `status` y `evidence` en `feature_list.json` y agrega una sección a `progress.md`.

## Orden de los changes

1. `bootstrap-harness`
2. `products-service-fastapi`
3. `orders-service-go`
4. `frontend-angular` (incluye `docker-compose.yml`)
5. `infra-aws-terraform` (incluye `infra/terraform/argocd`)
6. `gitops-manifests` (repo `../store-gitops`)
7. `ci-github-actions`
8. `demo-visible-change`
