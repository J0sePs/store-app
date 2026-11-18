# Guion de la exposición (10 minutos)

Proyecto: **store-app**, microservicios en AWS EKS con GitOps. Los diagramas están en [`docs/architecture.md`](architecture.md): **D1** es la arquitectura en AWS, **D2** el flujo GitOps y **D3** la comunicación entre componentes.

> **Importante:** la infraestructura de AWS ya está destruida (para no pagar). La demo es el **video grabado** (`VIDEO-HARNESS-CLAUDE-2-MICROSERVICIOS-GITOPS.mp4`, en la raíz del repositorio). Todo lo que digo se puede comprobar en el código y en las especificaciones.

## Resumen de tiempos

| # | Sección | Tiempo | Diagrama |
|---|---|---|---|
| 1 | Problema | 1:00 | — |
| 2 | Arquitectura | 1:15 | D1 |
| 3 | Microservicios y database-per-service | 1:00 | D3 |
| 4 | Spec-driven con OpenSpec | 1:15 | tabla de changes (sección 5 de `architecture.md`) |
| 5 | Terraform (IaC) | 1:00 | D1 |
| 6 | CI con GitHub Actions y OIDC | 1:15 | D2 |
| 7 | GitOps con Argo CD | 1:15 | D2 |
| 8 | Demo (video) | 1:30 | D2 y el video |
| 9 | Conclusiones | 0:30 | — |
| | **Total** | **10:00** | |

---

## 1. Problema (1:00)

**Lo que digo:**
"Quería resolver un problema muy común: cómo llevar un sistema de varios servicios a la nube de forma **repetible, auditable y sin pasos manuales**. Construí una tienda con un frontend y dos microservicios, y la desplegué en AWS con un flujo en el que **hacer `git push` es suficiente para publicar**: nadie ejecuta `kubectl apply` ni copia credenciales. Además lo desarrollé con especificaciones antes del código, para poder demostrar qué hace cada pieza."

**Conceptos:**

| Concepto | Qué es | Dónde lo apliqué | Por qué |
|---|---|---|---|
| GitOps | Git es la única fuente de verdad del clúster | `store-gitops` y `argocd/root-app.yaml` | Cada cambio queda auditado y se puede revertir |
| Microservicios | Servicios pequeños e independientes | `products-service/`, `orders-service/`, `frontend/` | Despliegue y fallos independientes |

## 2. Arquitectura (1:15) — mostrar **D1**

**Lo que digo:**
"Esta es la arquitectura que desplegué en `us-east-1`. Hay una VPC con dos zonas de disponibilidad y **un solo NAT** para ahorrar costo. Dentro, un clúster **EKS** con **dos nodos `t3.small`**. En el namespace `store` corren cinco pods: el frontend, los dos servicios y una base de datos PostgreSQL por servicio, cada una con su volumen `gp3`. En el namespace `argocd` está Argo CD. Las imágenes viven en **ECR** y el usuario entra por un balanceador de AWS que apunta al frontend."

**Conceptos:**

| Concepto | Qué es | Dónde lo apliqué | Por qué |
|---|---|---|---|
| EKS con nodos administrados | Kubernetes gestionado por AWS | `infra/terraform/eks.tf` | AWS opera el plano de control |
| Capacidad limitada | 11 pods y ≈ 1,4 GiB por nodo | `scripts/check-capacity.py`, `openspec/specs/cluster-capacity/` | Mi cuenta es del plan Gratuito: usé `t3.small` y calculé que todo cabe (17 de 22 pods, 46 % de memoria) |

## 3. Microservicios y database-per-service (1:00) — mostrar **D3**

**Lo que digo:**
"El navegador habla con un solo origen: **nginx**, que sirve la aplicación Angular y reenvía `/api/products` a `products-service`, escrito en **FastAPI**, y `/api/orders` a `orders-service`, escrito en **Go**. Cada servicio tiene **su propia base de datos** y nunca consulta la del otro: es el patrón *database-per-service*. Un pedido guarda solo el `product_id`, sin consultar al otro servicio. Todos exponen `GET /health`, que Kubernetes usa como probe."

**Conceptos:**

| Concepto | Qué es | Dónde lo apliqué | Por qué |
|---|---|---|---|
| Database-per-service | Cada servicio es dueño de sus datos | `store-gitops/apps/products-db/` y `apps/orders-db/` | Independencia y límites claros; el costo es no tener claves foráneas entre servicios |
| Proxy inverso | nginx reenvía `/api/...` a cada servicio | `frontend/nginx.conf` | Un solo origen, sin CORS |
| `/health` | Endpoint de salud con la versión | `products-service/app/api/health.py` | Probes de Kubernetes y versión visible en el pie |

## 4. Spec-driven con OpenSpec (1:15) — mostrar la tabla de changes

**Lo que digo:**
"No escribí código sin una especificación. Cada funcionalidad pasa por un *change* de **OpenSpec**: se **propone**, yo lo reviso, se **aplica** con pruebas y se **archiva**. Terminé con **10 changes archivados, 21 capacidades, 80 requisitos y 237 escenarios** verificables. Y lo más interesante: **dos changes nacieron de errores reales** del despliegue. El plan Gratuito de AWS no permitía `t3.medium`, y GitHub usaba un sujeto OIDC distinto del que esperaba mi rol. En vez de parchear, lo diagnostiqué, lo especifiqué y lo corregí dejando constancia."

**Conceptos:**

| Concepto | Qué es | Dónde lo apliqué | Por qué |
|---|---|---|---|
| OpenSpec | Propuesta, specs, diseño y tareas por cada cambio | `openspec/changes/archive/` y `openspec/specs/` | Requisitos verificables antes del código |
| Escenarios WHEN/THEN | Criterios de aceptación comprobables | `openspec/specs/*/spec.md` | Cada requisito se prueba con un test o un comando |

## 5. Terraform (1:00) — mostrar **D1**

**Lo que digo:**
"Toda la infraestructura es **código con Terraform**, usando los **módulos oficiales** de `terraform-aws-modules`: VPC, EKS, ECR e IAM. Hay **dos etapas** con estado separado: la principal crea la red, el clúster, los repositorios y el acceso de la CI; la segunda instala Argo CD, porque necesita un clúster ya existente. Antes de aplicar siempre hice `plan` y lo revisé con `terraform show -json`: por ejemplo, comprobé que un cambio solo modificaba una política de IAM y no reemplazaba nada. Y como el costo importa, calculé las horas y **al terminar destruí todo**."

**Conceptos:**

| Concepto | Qué es | Dónde lo apliqué | Por qué |
|---|---|---|---|
| IaC | La infraestructura descrita en archivos | `infra/terraform/*.tf` | Repetible y revisable |
| Dos etapas | Estados independientes | `infra/terraform/` y `infra/terraform/argocd/` | Los proveedores `helm` y `kubernetes` necesitan un clúster ya creado |
| Plan antes de apply | Ver el efecto antes de aplicar | `infra/terraform/README.md` | Evitar sorpresas y costos |

## 6. CI con GitHub Actions y OIDC (1:15) — mostrar **D2**

**Lo que digo:**
"En cada push a `main` que toca un componente, se lanza **su** workflow: primero lint y pruebas; luego se construye la imagen y se publica en ECR con el **SHA corto como única etiqueta**, nunca `latest`. Para entrar a AWS **no uso llaves de acceso**: GitHub emite un token **OIDC** y AWS entrega credenciales temporales a un rol que **solo acepta mi repositorio y la rama `main`**. Si el push a ECR sale bien, el último paso actualiza el repositorio `store-gitops` con `kustomize edit set image` y hace commit."

**Conceptos:**

| Concepto | Qué es | Dónde lo apliqué | Por qué |
|---|---|---|---|
| OIDC | Identidad federada: GitHub prueba quién es y AWS da credenciales temporales | `infra/terraform/github-oidc.tf` y `.github/workflows/_deploy-component.yml` | No hay secretos de AWS que filtrar o rotar |
| Etiqueta = SHA | Cada imagen identifica su commit | `.github/workflows/_deploy-component.yml` | Trazabilidad y rollback exactos |
| Workflow reutilizable | Los pasos sensibles están una sola vez | `_deploy-component.yml` y `.github/scripts/update-gitops.sh` | Menos duplicación y reintentos con `pull --rebase` |

## 7. GitOps con Argo CD (1:15) — mostrar **D2**

**Lo que digo:**
"Argo CD vive dentro del clúster y vigila `store-gitops`. Yo apliqué **una sola vez** una Application raíz, un patrón llamado **app-of-apps**, que crea una Application por componente, todas con sincronización **automática, `prune` y `selfHeal`**. Desde ahí, cuando la CI cambia un tag, Argo CD lo detecta, hace un **rolling update sin corte** y, si alguien toca el clúster a mano, lo vuelve a dejar como está en git. Una decisión que me gusta: Kustomize copia el tag de la imagen a la variable **`APP_VERSION`**, así que la versión que muestra el pie de la aplicación es siempre la desplegada."

**Conceptos:**

| Concepto | Qué es | Dónde lo apliqué | Por qué |
|---|---|---|---|
| App-of-apps | Una Application raíz crea las demás | `store-gitops/argocd/root-app.yaml` y `argocd/apps/` | Un único paso manual |
| `selfHeal` y `prune` | Revierte cambios manuales y borra lo que ya no está en git | `store-gitops/argocd/apps/*.yaml` | El clúster refleja siempre a git |
| Kustomize con `replacements` | `APP_VERSION` = tag de la imagen | `store-gitops/apps/*/kustomization.yaml` | La versión nunca se desincroniza |

## 8. Demo (1:30) — mostrar el **video** y **D2**

**Lo que digo (mientras corre el video):**
"Aquí hago un cambio pequeño y visible: un **banner** que dice «Versión 2 - desplegada con GitOps» y una columna **Categoría**. Hago `git push`. Se lanzan dos workflows, uno por componente. Las imágenes aparecen en ECR con el SHA nuevo y la CI hace dos commits `deploy(...)` en `store-gitops`. Argo CD pasa de *OutOfSync* a *Synced* y hace el rolling update. Un detalle importante: el servicio de productos tiene una **migración** que añade la columna a la base que ya existía en AWS, sin perder datos: la probé antes contra una PostgreSQL real, incluso comprobando que la versión anterior sigue funcionando sobre la base migrada. Al final el navegador muestra el banner, la categoría y las versiones nuevas en el pie."

**Qué comprobar en el video:** workflows en verde → imagen nueva en ECR → commit `deploy(...)` en `store-gitops` → Argo CD `Synced` → pods nuevos → banner y columna "Categoría".

## 9. Conclusiones (0:30)

**Lo que digo:**
"Logré un flujo donde **un `git push` publica una versión nueva** de forma segura, sin credenciales estáticas ni pasos manuales, con una infraestructura que se crea y se destruye con código. Lo desarrollé con especificaciones y dejé evidencia de cada paso. Lo que **queda pendiente** está marcado: HTTPS y dominio, estado de Terraform remoto, gestión de secretos con AWS Secrets Manager, bases de datos administradas con copias de seguridad, observabilidad y escalado automático."

---

## Diez preguntas probables y respuestas cortas

1. **¿Por qué dos repositorios (`store-app` y `store-gitops`)?**
   Separo el *código* del *estado deseado del clúster*. Argo CD solo vigila `store-gitops`, que contiene únicamente manifiestos, y la CI es lo único que lo modifica. Así el historial de despliegues está limpio (cada commit `deploy(...)` es un despliegue) y se puede dar permisos distintos a cada repositorio.

2. **¿Por qué no usas la etiqueta `latest`?**
   Porque no dice qué versión corre ni permite volver atrás. Cada imagen lleva el **SHA corto** del commit, y `APP_VERSION` coincide con él: sé exactamente qué está desplegado. Además `latest` no cambia el manifiesto, así que Argo CD no vería diferencias.

3. **¿Cómo hago un rollback?**
   Con `git revert` del commit `deploy(...)` en `store-gitops`: Argo CD sincroniza solo y vuelve a la imagen anterior. Las imágenes viejas siguen en ECR (se conservan las últimas 10). Probé que la versión anterior del servicio funciona incluso sobre la base ya migrada.

4. **¿Qué pasa si alguien edita el clúster a mano?**
   Con `selfHeal` activo, Argo CD detecta la diferencia y lo revierte al estado de git. Para cambiar algo de forma permanente hay que cambiarlo en `store-gitops`.

5. **¿Por qué OIDC y no access keys?**
   Las llaves estáticas se filtran, caducan mal y dan acceso permanente. Con OIDC, GitHub demuestra su identidad y AWS entrega credenciales **temporales** a un rol cuya política solo acepta mi repositorio y la rama `main`, y solo permite subir imágenes a ECR. En la práctica tuve que ajustar la política porque GitHub emite el sujeto con ids numéricos (sujeto inmutable), lo que además protege contra el *repo-jacking*.

6. **¿Cómo escalarías esto?**
   Subiendo réplicas y nodos (`node_desired_size` en Terraform) y añadiendo HPA y un autoescalador de nodos, que hoy **no existen**. Con más volumen cambiaría los StatefulSets por RDS con copias de seguridad, pondría un Ingress con HTTPS y un backend remoto para el estado de Terraform.

7. **¿Cómo mantienes la integridad entre servicios sin claves foráneas?**
   Es el costo del database-per-service: un pedido guarda solo `product_id` y el servicio de pedidos no valida que exista. Es una decisión explícita y documentada; para validarlo habría que llamar a la API de productos o usar eventos.

8. **¿Qué pasa si la migración de la base falla durante un despliegue?**
   El pod nuevo no arranca, pero como el rolling update usa `maxUnavailable: 0` el pod viejo sigue sirviendo: no hay corte. Además la migración es idempotente (`ADD COLUMN IF NOT EXISTS`) y la columna tiene valor por defecto, así que la versión anterior sigue funcionando.

9. **¿Cómo manejas los secretos?**
   Ninguno va a git. Las contraseñas de las bases se generan al momento con `openssl rand` y se crean con `kubectl create secret`; los workflows usan OIDC, y el token que escribe en `store-gitops` es un secret de GitHub limitado a ese repositorio. Es una solución simple: lo pendiente es integrarlo con AWS Secrets Manager.

10. **¿Qué fue lo más difícil o lo que más aprendiste?**
    Los fallos reales del despliegue: el plan Gratuito de AWS bloqueó `t3.medium` y rediseñé el sistema para caber en `t3.small` con un presupuesto de pods y memoria; y el login de la CI falló por el formato del sujeto OIDC. Aprendí a **diagnosticar con datos antes de corregir** y a dejar cada decisión en una especificación.

---

## Nota: convención de idioma y el rol de `AGENTS.md` y `CLAUDE.md`

**Convención de idioma** (obligatoria en el proyecto, definida en `AGENTS.md` y `openspec/config.yaml`):

- **En inglés:** nombres de carpetas y archivos, código (variables, funciones, clases), endpoints, campos JSON, tablas y columnas, recursos de Kubernetes y Terraform, nombres de los changes, ramas y mensajes de commit.
- **En español:** comentarios del código, mensajes de log, errores que devuelve la API, texto de la interfaz, README, documentación en `docs/` y el contenido de los artefactos de OpenSpec.

La razón: el código y la infraestructura siguen las convenciones de la industria (y funcionan con las herramientas), mientras que lo que lee un usuario o un evaluador está en español.

**`AGENTS.md` y `CLAUDE.md`:**

- `AGENTS.md` es la **fuente única de verdad** de las reglas del proyecto para cualquier agente de IA (Claude Code, opencode…): arquitectura, reglas de GitOps que no se rompen (nada de `latest`, `kubectl apply` desde la CI ni llaves estáticas), acciones que requieren confirmación humana (`terraform apply/destroy`, `git push`), comandos por componente y definición de terminado.
- `CLAUDE.md` importa `AGENTS.md` y añade solo lo específico de Claude Code (los comandos de las skills de OpenSpec).
- Junto con `feature_list.json`, `progress.md` y `init.sh`, hacen que **cualquier agente retome el trabajo sin perder contexto** y sin salirse de las reglas.
