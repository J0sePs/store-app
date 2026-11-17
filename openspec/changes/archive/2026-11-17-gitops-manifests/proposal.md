## Why

La infraestructura ya está definida y la CI (siguiente change) necesita un destino: el repositorio `store-gitops`, que Argo CD vigila. Sin manifiestos y sin las Applications de Argo CD no hay nada que sincronizar con el clúster. Este change entrega ese contenido para que, cuando CI actualice el tag de una imagen, Argo CD la despliegue sola.

## What Changes

En `../store-gitops` (otro repositorio git, hoy sin commits):

- `apps/{frontend,products-service,orders-service,products-db,orders-db}/`, cada uno con `kustomization.yaml`.
- **Deployments** (frontend, products-service, orders-service) con probes en `/health`, `requests`/`limits` y contenedor sin root. `APP_VERSION` se toma del tag de la imagen mediante un `replacements` de Kustomize: cuando CI ejecuta `kustomize edit set image`, la versión que muestran `/health` y el pie de página cambia sola.
- **Bases de datos** como `StatefulSet` con PVC `gp3` y Service headless (`products-db`, `orders-db`).
- **Services:** el frontend como `LoadBalancer` (puerto 80 → 8080); el resto `ClusterIP`.
- `argocd/`: Application raíz (`root-app.yaml`, app-of-apps) y una Application por componente, con `automated`, `prune` y `selfHeal`, namespace `store`.
- Las credenciales de las bases **no** van a git: Secrets creados con `kubectl create secret`.
- `README.md` en español: crear los Secrets, registrar el repo en Argo CD, entrar a su UI y cómo actualiza la CI las imágenes.

En `store-app` (cambio pequeño y necesario): el frontend no tenía `/health`; se agrega en nginx (`{"status":"ok","version":"<APP_VERSION>"}`) para cumplir la regla de probes y de `GET /health`.

Supuestos (ver design): `repoURL` `https://github.com/J0sePs/store-gitops.git` (el remoto ya configurado), rama `main`; frontend con 2 réplicas y servicios con 1; imágenes con una cuenta de ECR de marcador que CI reemplaza.

No hay cambios **BREAKING**.

## Capabilities

### New Capabilities

- `k8s-workloads`: Deployments y Services de los tres componentes (probes, recursos, `APP_VERSION`, exposición).
- `k8s-databases`: StatefulSets de PostgreSQL con PVC `gp3`, Service headless y credenciales fuera de git.
- `argocd-applications`: app-of-apps con sincronización automática.
- `gitops-operations`: contrato con la CI (cómo se actualizan las imágenes) y README operativo.

### Modified Capabilities

- `frontend-proxy`: añade el requisito de `GET /health` del frontend.

## Impact

- **Componentes afectados:** repo `../store-gitops` (nuevo contenido); `frontend/nginx.conf` y `frontend/Dockerfile` en `store-app`.
- **Dependencias:** Kustomize (vía `kubectl kustomize`), Argo CD ya instalado por el change de infraestructura.
- **Fuera de alcance:** workflows de CI, aplicar nada en el clúster (`kubectl apply`), HTTPS y dominio.
- **Archivos del repo:** `feature_list.json` y `progress.md`; commits y push de ambos repos los hace el humano.
