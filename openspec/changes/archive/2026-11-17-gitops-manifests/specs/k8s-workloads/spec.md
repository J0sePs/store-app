## ADDED Requirements

### Requirement: Estructura de cada componente

El repositorio `store-gitops` SHALL tener `apps/frontend`, `apps/products-service`, `apps/orders-service`, `apps/products-db` y `apps/orders-db`, cada uno con su `kustomization.yaml` y capaz de construirse con `kubectl kustomize apps/<nombre>` sin errores. Todos los recursos SHALL pertenecer al namespace `store` y llevar las etiquetas `app.kubernetes.io/name` y `app.kubernetes.io/part-of: store`.

#### Scenario: Construcción
- **WHEN** se ejecuta `kubectl kustomize apps/<nombre>` para cada uno de los cinco componentes
- **THEN** termina sin errores y produce manifiestos de Kubernetes válidos

#### Scenario: Namespace y etiquetas
- **WHEN** se revisan los recursos construidos
- **THEN** todos tienen `namespace: store` y la etiqueta `app.kubernetes.io/part-of: store`

### Requirement: Deployments con probes y recursos

Los Deployments de `frontend`, `products-service` y `orders-service` SHALL definir `readinessProbe` y `livenessProbe` HTTP sobre `/health` en el puerto del contenedor (8080, 8000 y 8080 respectivamente), `resources.requests` y `resources.limits` de CPU y memoria, un `securityContext` que no permita ejecutar como root ni escalar privilegios, y una estrategia `RollingUpdate` con `maxUnavailable: 0`. El frontend SHALL tener 2 réplicas y cada servicio 1, para evitar que dos instancias creen a la vez la tabla y los datos iniciales al primer arranque.

#### Scenario: Probes
- **WHEN** se revisa cada Deployment construido
- **THEN** sus probes de readiness y liveness usan `httpGet` en la ruta `/health`

#### Scenario: Recursos
- **WHEN** se revisa cada contenedor
- **THEN** define `requests` y `limits` de `cpu` y `memory`

#### Scenario: Sin root
- **WHEN** se revisa el `securityContext`
- **THEN** `runAsNonRoot` es `true` y `allowPrivilegeEscalation` es `false`

#### Scenario: Actualización sin corte
- **WHEN** se actualiza la imagen de un Deployment
- **THEN** la estrategia levanta el pod nuevo antes de retirar el anterior (`maxUnavailable: 0`)

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
