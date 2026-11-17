# Prompts del proyecto (guía de trabajo)

Prompts usados para construir el proyecto con desarrollo guiado por specs (OpenSpec) y un agente de IA.

> **Comandos según la herramienta**
> - Claude Code: `/openspec-propose`, `/openspec-apply-change`, `/openspec-archive-change`
> - opencode: mismos nombres de skill (`openspec-propose`, `openspec-apply-change`, `openspec-archive-change`); confírmalo con el autocompletado
>
> **Ciclo de cada change:** `propose` → revisas `openspec/changes/<name>/` → `apply` → pruebas → `archive` → commit.

---

## 0. Inicio de sesión

```
Lee AGENTS.md, openspec/config.yaml y la skill harness (si existe) y síguelas durante todo el proyecto.
Resúmeme en 10 líneas la arquitectura que vamos a construir y el orden de los changes.
Confirma que tienes acceso de escritura a ../store-gitops. No escribas código todavía.
```

---

## Change 1: products-service (FastAPI)

```
/openspec-propose products-service-fastapi
Microservicio de productos en products-service/ con FastAPI y su propia PostgreSQL.
- Endpoints: GET /products, GET /products/{id}, POST /products, GET /health (status + version desde la env APP_VERSION).
- Modelo Product: id, name, price, stock, created_at. Crea la tabla al arrancar y siembra 3 productos de ejemplo.
- DATABASE_URL por variable de entorno. Puerto 8000.
- Tests con pytest. Dockerfile multi-stage con usuario no root. README en español.
- Identificadores y archivos en inglés; comentarios, logs y mensajes de error en español.
```

## Change 2: orders-service (Go)

```
/openspec-propose orders-service-go
Microservicio de pedidos en orders-service/ con Go, chi y pgx, y su propia PostgreSQL.
- Endpoints: GET /orders, GET /orders/{id}, POST /orders, GET /health (status + version desde APP_VERSION).
- Modelo Order: id, product_id (solo una referencia, sin consultar al otro servicio ni a su BD), quantity, customer, status, created_at.
- Migración al arrancar. DATABASE_URL por variable de entorno. Puerto 8080.
- Tests con go test y httptest. Dockerfile multi-stage con imagen final distroless. README en español.
- Identificadores y archivos en inglés; comentarios, logs y mensajes de error en español.
```

## Change 3: frontend + docker-compose

```
/openspec-propose frontend-angular
Frontend en frontend/ con Angular que consume AMBOS servicios.
- Componentes en inglés (products-page, orders-page, version-footer, etc.); el texto visible para el usuario en español.
- Vista de productos (listar y crear) y vista de pedidos (listar y crear, eligiendo un producto de la lista).
- Pie de página con la versión del frontend y la de cada servicio (llamando a /health). Se usará en el video.
- Llamadas relativas a /api/products y /api/orders. nginx.conf hace de proxy hacia products-service:8000 y orders-service:8080.
- Dockerfile multi-stage: build con node y servido con nginx.
- docker-compose.yml en la raíz con frontend, products-service, products-db, orders-service y orders-db.
```

**Prueba local antes de seguir:** `docker compose up --build` y abre http://localhost.

## Change 4: infraestructura con Terraform

```
/openspec-propose infra-aws-terraform
Infraestructura en infra/terraform según openspec/config.yaml:
- Módulos terraform-aws-modules/vpc y terraform-aws-modules/eks.
- 3 repos ECR (frontend, products-service, orders-service) con scan on push y lifecycle policy (conservar las últimas 10 imágenes).
- Addon EBS CSI con sus permisos IAM, y StorageClass gp3.
- Proveedor OIDC de GitHub y un rol IAM que solo pueda asumir <MY_USER>/store-app en la rama main, con permiso de push a los 3 ECR.
- Etapa separada infra/terraform/argocd que instala Argo CD con helm_release.
- variables.tf, outputs.tf (cluster name, ECR URLs, role ARN) y terraform.tfvars.example. Recursos y variables en inglés, comentarios en español.
- README en español con los pasos de apply y destroy, el costo estimado por hora y la advertencia de borrar los Services LoadBalancer antes de hacer destroy.
Solo genera el código y ejecuta terraform fmt/validate. NO ejecutes apply.
```

## Change 5: repo GitOps (../store-gitops)

```
/openspec-propose gitops-manifests
Genera el contenido del repo DevOps en ../store-gitops (es otro repositorio git):
- apps/frontend, apps/products-service, apps/orders-service, apps/products-db y apps/orders-db, cada uno con su kustomization.yaml.
- Deployments con probes en /health, requests/limits y APP_VERSION igual al tag de la imagen.
- Las BD como StatefulSet con PVC gp3 y un Service headless.
- Frontend expuesto con un Service tipo LoadBalancer; el resto como ClusterIP.
- argocd/: un Application raíz (app-of-apps) más una Application por componente, con automated, prune y selfHeal. Namespace "store".
- README en español con los comandos kubectl create secret para las BD, cómo registrar el repo en Argo CD y cómo entrar a su UI.
```

## Change 6: CI con GitHub Actions

```
/openspec-propose ci-github-actions
Workflows en .github/workflows/ (frontend.yml, products-service.yml, orders-service.yml):
- Disparo: push a main con un filtro de paths por componente.
- Pasos: tests -> login a AWS por OIDC (aws-actions/configure-aws-credentials) -> build -> push a ECR con tag = SHA corto.
- Después: checkout de <MY_USER>/store-gitops con el secret GITOPS_TOKEN -> kustomize edit set image -> actualizar APP_VERSION
  -> commit "deploy(<service>): <sha>" -> push (con pull --rebase y reintento).
- El paso de gitops solo se ejecuta si el push a ECR salió bien.
- Nombres de jobs y steps en inglés; los mensajes echo en español. Documenta en el README los secrets que hay que crear.
```

---

## Despliegue en AWS (lo ejecutas tú, en este orden)

1. `cd infra/terraform && terraform init && terraform apply`
2. `aws eks update-kubeconfig --name <cluster> --region us-east-1`
3. `cd argocd && terraform init && terraform apply`
4. Crear los secrets de BD (comandos en el README de store-gitops).
5. `kubectl apply -f ../store-gitops/argocd/root-app.yaml` (bootstrap manual, una sola vez).
6. En GitHub: crear el secret `GITOPS_TOKEN` y la variable con el ARN del rol (`AWS_ROLE_ARN`).
7. Hacer push de store-gitops y luego de store-app. Ver los workflows en Actions.

## Verificación

```
Audita en modo solo lectura si el sistema cumple la arquitectura GitOps de AGENTS.md:
1. Workflows: disparo, push a ECR con tag SHA y actualización de ../store-gitops después del push.
2. store-gitops: ¿los tags de los manifiestos existen en ECR? (aws ecr describe-images)
3. Argo CD: kubectl get applications -n argocd (Sync, Health, syncPolicy).
4. EKS: kubectl get deploy,pods,svc -n store -o wide (imágenes desde ECR, pods sin errores).
Dame una tabla por componente: ✅ / ⚠️ / ❌ con la evidencia encontrada. No modifiques nada.
```

---

## Change de demo (para el video)

```
/openspec-propose demo-visible-change
Cambio pequeño y visible para demostrar GitOps: agrega en el frontend un banner con el texto
"Versión 2 - desplegada con GitOps" y agrega el campo category al modelo Product en FastAPI
(con su migración, el test actualizado y mostrándolo en la tabla del frontend con el encabezado "Categoría").
```

**Guion del video:**

1. App funcionando con la versión 1.
2. `git push`.
3. GitHub Actions ejecutándose.
4. La imagen nueva en ECR con el SHA como tag.
5. El commit automático en store-gitops.
6. Argo CD pasando de OutOfSync a Synced.
7. `kubectl get pods -n store -w` mostrando el rolling update.
8. El navegador con el banner y las versiones nuevas en el pie de página.

---

## Documentación de arquitectura (Mermaid)

```
Analiza el repositorio real (store-app, ../store-gitops, infra/terraform, openspec/) y crea docs/architecture.md
(contenido en español) con:
1. Diagrama Mermaid de la arquitectura en AWS (VPC, EKS, nodos, namespace store, pods, BD, ECR, LoadBalancer, Argo CD).
2. sequenceDiagram del flujo GitOps: dev -> GitHub Actions -> ECR -> store-gitops -> Argo CD -> EKS -> pull a ECR.
3. Diagrama de comunicación: navegador -> nginx/frontend -> products-service/orders-service -> cada BD.
4. Una tabla de tecnologías con el porqué de cada elección.
5. Una sección "Desarrollo guiado por specs" que liste los changes de openspec/changes/archive y lo que definió cada uno.
Todo debe salir del código real. Si algo no existe, márcalo como pendiente; no lo inventes.
```

## Exposición

```
Lee docs/architecture.md, AGENTS.md, openspec/ (config.yaml y changes archivados), infra/terraform, .github/workflows y ../store-gitops.
Crea docs/presentation.md (contenido en español) para una exposición de 10 minutos con:
1. Guion por secciones, con lo que debo decir en primera persona y el tiempo de cada sección:
   problema -> arquitectura -> microservicios y database-per-service -> spec-driven con OpenSpec ->
   Terraform (IaC) -> CI con GitHub Actions + OIDC -> GitOps con Argo CD -> demo -> conclusiones.
2. Para cada concepto: qué es, dónde lo apliqué (archivo concreto) y por qué.
3. Qué diagrama de docs/architecture.md mostrar en cada momento.
4. Diez preguntas probables del profesor, con respuestas cortas (por qué dos repos, por qué no latest, cómo hago rollback,
   qué pasa si alguien edita el clúster a mano, por qué OIDC y no access keys, cómo escalaría esto).
5. Una nota que explique la convención de idioma del proyecto y el rol de AGENTS.md / CLAUDE.md.
```

---

## Al terminar: apagar AWS (evitar cobros)

```bash
kubectl delete svc frontend -n store          # libera el LoadBalancer
cd infra/terraform/argocd && terraform destroy
cd .. && terraform destroy
```
