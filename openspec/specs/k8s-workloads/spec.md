# k8s-workloads Specification

## Purpose
Deployments y Services de frontend, products-service y orders-service en el namespace store: probes en /health, recursos, contenedores sin root, APP_VERSION igual al tag de la imagen y exposición del frontend con un balanceador.

## Requirements

### Requirement: Estructura de cada componente

El repositorio `store-gitops` SHALL tener `apps/frontend`, `apps/products-service`, `apps/orders-service`, `apps/products-db` y `apps/orders-db`, cada uno con su `kustomization.yaml` y capaz de construirse con `kubectl kustomize apps/<nombre>` sin errores. Todos los recursos SHALL pertenecer al namespace `store` y llevar las etiquetas `app.kubernetes.io/name` y `app.kubernetes.io/part-of: store`.

#### Scenario: Construcción
- **WHEN** se ejecuta `kubectl kustomize apps/<nombre>` para cada uno de los cinco componentes
- **THEN** termina sin errores y produce manifiestos de Kubernetes válidos

#### Scenario: Namespace y etiquetas
- **WHEN** se revisan los recursos construidos
- **THEN** todos tienen `namespace: store` y la etiqueta `app.kubernetes.io/part-of: store`

### Requirement: Deployments con probes y recursos

Los Deployments de `frontend`, `products-service` y `orders-service` SHALL definir `readinessProbe` y `livenessProbe` HTTP sobre `/health` en el puerto del contenedor (8080, 8000 y 8080 respectivamente), `resources.requests` y `resources.limits` de CPU y memoria, un `securityContext` que no permita ejecutar como root ni escalar privilegios, y una estrategia `RollingUpdate` con `maxSurge: 1` y `maxUnavailable: 0`. Cada Deployment SHALL tener 1 réplica: el clúster de 2 nodos `t3.small` solo admite 22 pods, y además un solo pod evita que dos instancias creen a la vez la tabla y los datos iniciales al primer arranque. Los `requests` de memoria SHALL ser 96 MiB para `products-service` y 32 MiB para `orders-service` y para el frontend, con límites de 192 MiB, 64 MiB y 64 MiB respectivamente.

#### Scenario: Probes
- **WHEN** se revisa cada Deployment construido
- **THEN** sus probes de readiness y liveness usan `httpGet` en la ruta `/health`

#### Scenario: Recursos
- **WHEN** se revisa cada contenedor
- **THEN** define `requests` y `limits` de `cpu` y `memory`, con el límite de memoria mayor o igual que el `request`

#### Scenario: Memoria ajustada
- **WHEN** se revisan los `requests` de memoria
- **THEN** `products-service` pide 96Mi y `orders-service` y el frontend piden 32Mi

#### Scenario: Una réplica
- **WHEN** se revisan los tres Deployments
- **THEN** cada uno tiene `replicas: 1`

#### Scenario: Sin root
- **WHEN** se revisa el `securityContext`
- **THEN** `runAsNonRoot` es `true` y `allowPrivilegeEscalation` es `false`

#### Scenario: Actualización sin corte
- **WHEN** se actualiza la imagen de un Deployment
- **THEN** la estrategia levanta el pod nuevo (`maxSurge: 1`) antes de retirar el anterior (`maxUnavailable: 0`), aunque haya una sola réplica

### Requirement: APP_VERSION igual al tag de la imagen

Cada Deployment SHALL recibir la variable de entorno `APP_VERSION` con el mismo valor que el tag de su imagen, sin editarla a mano: Kustomize SHALL copiarla del campo `image` ya transformado por `images`. Las imágenes SHALL referenciarse por un nombre lógico (`frontend`, `products-service`, `orders-service`) y definirse en `images` del `kustomization.yaml` con `newName` (repositorio ECR) y `newTag` (SHA corto). La etiqueta `latest` NO SHALL usarse.

#### Scenario: Versión igual al tag
- **WHEN** `newTag` vale `abc1234` y se construye el componente
- **THEN** la imagen termina en `:abc1234` y `APP_VERSION` vale `abc1234`

#### Scenario: Cambio de tag
- **WHEN** se cambia `newTag` a `f00ba42` y se construye de nuevo
- **THEN** la imagen y `APP_VERSION` valen `f00ba42`, sin tocar ningún otro archivo

#### Scenario: Sin latest
- **WHEN** se buscan las etiquetas de imagen del repositorio
- **THEN** ninguna es `latest`

### Requirement: Exposición de los Services

El Service del frontend SHALL ser de tipo `LoadBalancer`, con puerto 80 hacia el puerto 8080 del contenedor. `products-service` (puerto 8000) y `orders-service` (puerto 8080) SHALL ser `ClusterIP` y llamarse exactamente así, porque nginx del frontend los resuelve por nombre.

#### Scenario: Tipos de Service
- **WHEN** se revisan los Services construidos
- **THEN** `frontend` es `LoadBalancer` y `products-service` y `orders-service` son `ClusterIP`

#### Scenario: Nombres
- **WHEN** se revisan los nombres de los Services de los servicios
- **THEN** se llaman `products-service` y `orders-service`

### Requirement: Configuración solo por entorno

Los servicios SHALL recibir `DATABASE_URL` desde un Secret (`products-db-credentials`, `orders-db-credentials`), nunca como valor escrito en el manifiesto.

#### Scenario: DATABASE_URL desde Secret
- **WHEN** se revisa el Deployment de un servicio
- **THEN** `DATABASE_URL` usa `valueFrom.secretKeyRef` y ningún manifiesto contiene la URL ni una contraseña
