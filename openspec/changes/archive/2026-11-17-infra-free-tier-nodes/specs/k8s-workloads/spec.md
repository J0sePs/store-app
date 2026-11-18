## MODIFIED Requirements

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
