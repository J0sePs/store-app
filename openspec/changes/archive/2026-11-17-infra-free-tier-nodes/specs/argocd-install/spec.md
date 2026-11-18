## ADDED Requirements

### Requirement: Argo CD con huella reducida

La instalación de Argo CD SHALL ajustarse a nodos pequeños: `dex` y `notifications` desactivados (`enabled: false`), el controlador de ApplicationSet con 0 réplicas (el chart no ofrece un `enabled` propio), 1 réplica en el controlador, el repo-server, el server y redis, y `requests`/`limits` de CPU y memoria en los 4 componentes que quedan. Los pods de larga vida de Argo CD SHALL ser 4. Estos valores SHALL pasarse como `values` del `helm_release`, y las claves SHALL existir en el `values.yaml` de la versión del chart fijada.

#### Scenario: Pods de Argo CD
- **WHEN** se renderiza el chart con los valores (`helm template`) y se cuentan los Deployments y StatefulSets con réplicas mayores que 0
- **THEN** hay 4: controlador, repo-server, server y redis

#### Scenario: Componentes desactivados
- **WHEN** se revisan los valores
- **THEN** `dex.enabled` y `notifications.enabled` son `false` y `applicationSet.replicas` es `0`

#### Scenario: Recursos definidos
- **WHEN** se revisan los contenedores renderizados de los 4 componentes
- **THEN** todos tienen `requests` y `limits` de CPU y memoria

#### Scenario: Claves válidas
- **WHEN** se comparan las claves de los valores con el `values.yaml` del chart
- **THEN** todas existen en esa versión del chart

#### Scenario: Argo CD sigue funcionando
- **WHEN** Argo CD tiene `dex` y `notifications` desactivados
- **THEN** se puede entrar a la UI con `kubectl port-forward` y el usuario `admin`, y sincronizar la `root-app`
