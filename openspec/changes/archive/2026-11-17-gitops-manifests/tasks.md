# Tasks

> Se edita `../store-gitops` (otro repositorio) y `store-app`. No se ejecuta `kubectl apply` ni nada contra el clúster. Los commits y el `git push` de ambos repositorios los hace el humano. En las verificaciones, `GITOPS` es la ruta `../store-gitops`.

## 1. Estado y andamiaje

- [x] 1.1 Marcar `gitops-manifests` como `in_progress` en `feature_list.json`; verificar con `./init.sh` que solo hay un change activo
- [x] 1.2 Confirmar acceso de escritura a `../store-gitops` y crear su estructura (`apps/{frontend,products-service,orders-service,products-db,orders-db}`, `argocd/apps`) y un `.gitignore` (secretos locales, `.env`, `secret.yaml`, `*.secret.yaml`, `*.key`); verificar con `git -C ../store-gitops check-ignore secret.yaml .env` y que el repo sigue sin commits

## 2. /health del frontend (store-app)

- [x] 2.1 Generar `health.json` en el Dockerfile del frontend junto a `version.json` (mismo `APP_VERSION` validado) y añadir `location = /health` en `frontend/nginx.conf` (`rewrite` a `/health.json`, `Cache-Control: no-store`); verificar con `nginx -t` de la imagen oficial usando `--add-host products-service:127.0.0.1 --add-host orders-service:127.0.0.1`
- [x] 2.2 Construir la imagen y probarla; verificar con `docker build --build-arg APP_VERSION=abc1234` que `GET /health` devuelve `{"status":"ok","version":"abc1234"}` con `no-store`, que sin el argumento devuelve `dev`, que responde 200 con los servicios caídos, y que `/version.json` y la SPA siguen funcionando
- [x] 2.3 Documentar `/health` en `frontend/README.md` y confirmar que `npm test -- --watch=false` y `docker compose --env-file .env.example config -q` siguen sin errores

## 3. Bases de datos

- [x] 3.1 Escribir `apps/products-db` (`kustomization.yaml`, `statefulset.yaml`, `service.yaml` headless): `postgres:16-alpine`, `volumeClaimTemplates` `gp3` de 5Gi, `PGDATA` en subdirectorio, `POSTGRES_PASSWORD` desde el Secret `products-db-credentials`, usuario 70, `pg_isready`, recursos y etiquetas; verificar con `kubectl kustomize GITOPS/apps/products-db` sin errores y que contiene `storageClassName: gp3` y `clusterIP: None`
- [x] 3.2 Escribir `apps/orders-db` con la misma estructura y su propio Secret (`orders-db-credentials`); verificar con `kubectl kustomize GITOPS/apps/orders-db` y que ningún recurso hace referencia a `products-db`

## 4. Servicios y frontend

- [x] 4.1 Escribir `apps/products-service` (`kustomization.yaml` con `images` y `replacements` de `APP_VERSION`, `deployment.yaml`, `service.yaml` `ClusterIP` 8000): probes `/health`, recursos, `securityContext` (uid 10001), `DATABASE_URL` desde el Secret `products-db-credentials`; verificar con `kubectl kustomize` que la imagen termina en `:0000000` y `APP_VERSION` vale `0000000`
- [x] 4.2 Escribir `apps/orders-service` (puerto 8080, uid 65532, Secret `orders-db-credentials`); verificar con `kubectl kustomize` igual que en 4.1 y que el Service se llama `orders-service`
- [x] 4.3 Escribir `apps/frontend` (2 réplicas, puerto 8080, uid 101, probes `/health`, Service `LoadBalancer` 80 → 8080); verificar con `kubectl kustomize` que el Service es `LoadBalancer` y que las probes usan `/health`
- [x] 4.4 Verificar `APP_VERSION` siguiendo al tag: en una copia temporal (directorio temporal del agente) cambiar `newTag` a `f00ba42` en cada componente con imagen y construir; verificar que la imagen y `APP_VERSION` pasan a `f00ba42` en los tres, sin tocar ningún otro archivo

## 5. Argo CD

- [x] 5.1 Escribir `argocd/apps/{frontend,products-service,orders-service,products-db,orders-db}.yaml` (origen `apps/<nombre>`, rama `main`, destino namespace `store`, `automated` con `prune` y `selfHeal`, `CreateNamespace=true`, finalizador); verificar con un script de Python que los cinco archivos cumplen esos campos
- [x] 5.2 Escribir `argocd/root-app.yaml` (origen `argocd/apps`, destino namespace `argocd`, misma política); verificar con Python que su ruta es `argocd/apps`, que no está dentro de esa carpeta y que `repoURL` coincide con `git -C ../store-gitops remote get-url origin`

## 6. README y comprobación final

- [x] 6.1 Escribir `GITOPS/README.md` en español: estructura, `kubectl create namespace store` y los dos `kubectl create secret generic` (contraseña con `openssl rand -hex 16`), registro del repo en Argo CD (público y privado), `kubectl apply -f argocd/root-app.yaml`, UI de Argo CD (contraseña inicial y `port-forward`), URL del frontend, cómo actualiza la CI las imágenes, y limpieza de PVC y balanceador antes de `terraform destroy`; verificar que los comandos documentados son sintácticamente válidos (`bash -n` sobre un archivo con ellos) y que no contienen contraseñas literales
- [x] 6.2 Comprobación integral sin clúster: `kubectl kustomize` de los cinco componentes y script de Python que verifica probes en `/health`, `requests`/`limits` en cada contenedor, `runAsNonRoot`, `gp3`, tipos de Service y la política de las Applications; verificar que no hay `kind: Secret`, contraseñas ni `latest` (`grep`) y que la verificación termina sin errores
- [x] 6.3 Actualizar `AGENTS.md` solo si cambia la estructura y confirmar con `./init.sh` que termina con código 0; ejecutar `openspec validate gitops-manifests`
- [x] 6.4 Cerrar el change: `feature_list.json` con `gitops-manifests` en `done` y `evidence`, nueva sección en `progress.md` (incluye el orden de despliegue y que los commits de ambos repos son del humano) y siguiente paso `ci-github-actions`; verificar que `ci-github-actions` queda `pending`

## Workflow follow-up

- Archivar con `/openspec-archive-change` tras la revisión del humano.
- Commits y `git push` de `store-gitops` y `store-app` solo con confirmación.
