## ADDED Requirements

### Requirement: Presupuesto de pods

El sistema completo SHALL caber en 2 nodos `t3.small`, cada uno con un máximo de 11 pods (22 en total), y SHALL dejar al menos 3 pods libres en régimen estable para los pods adicionales de un rolling update (`maxSurge: 1`). El número de pods en régimen estable SHALL ser como máximo 19. El cálculo SHALL contar los DaemonSets por nodo (`aws-node`, `kube-proxy`, `ebs-csi-node`), CoreDNS y el controlador EBS CSI con 1 réplica cada uno, los 4 pods de Argo CD (controlador, repo-server, server y redis) y los 5 de la aplicación (frontend, `products-service`, `orders-service`, `products-db` y `orders-db`).

#### Scenario: Pods en régimen estable
- **WHEN** se suman los pods esperados (6 de DaemonSets, 2 de kube-system, 4 de Argo CD y 5 de la aplicación)
- **THEN** el total es 17, quedan 5 libres de 22 y se cumple el mínimo de 3

#### Scenario: Rolling update de la demo
- **WHEN** el frontend y `products-service` se actualizan a la vez con `maxSurge: 1`
- **THEN** hay como máximo 2 pods adicionales (19 de 22) y siguen quedando 3 libres

#### Scenario: Ninguna réplica extra
- **WHEN** se revisan los manifiestos y los valores de Helm
- **THEN** ningún Deployment de la aplicación tiene más de 1 réplica y ningún componente de Argo CD, CoreDNS ni EBS CSI supera 1 réplica

### Requirement: Presupuesto de memoria

La suma de los `requests` de memoria de todos los pods en régimen estable SHALL ser como máximo el 70 % de la memoria asignable total de los 2 nodos (1 433 MiB cada uno medidos en el clúster real, 2 866 MiB en total), es decir, 2 000 MiB. Todo contenedor de la aplicación y de Argo CD SHALL tener `requests` y `limits` de CPU y memoria, con el `limit` de memoria mayor o igual que el `request`.

#### Scenario: Memoria solicitada
- **WHEN** se suman los `requests` de memoria del sistema (510 MiB, medidos en el clúster real), Argo CD (384 MiB) y la aplicación (416 MiB)
- **THEN** el total es 1 310 MiB, el 46 % de la memoria asignable y por debajo del 70 %

#### Scenario: Valores de la aplicación
- **WHEN** se revisan los `requests` de memoria de la aplicación
- **THEN** PostgreSQL pide 128 MiB, `products-service` 96 MiB, `orders-service` 32 MiB y el frontend 32 MiB

#### Scenario: Límites coherentes
- **WHEN** se revisa cada contenedor
- **THEN** su `limit` de memoria es mayor o igual que su `request`

### Requirement: Cálculo reproducible y documentado

El presupuesto SHALL poder recalcularse con un script a partir de los manifiestos de `store-gitops`, los valores de Helm de Argo CD y los valores conocidos de los addons, y SHALL quedar documentado en una tabla en `infra/terraform/README.md`, junto con una regla en `AGENTS.md`: antes de añadir un pod o subir una réplica hay que volver a calcular la capacidad.

#### Scenario: Script de capacidad
- **WHEN** se ejecuta el script de capacidad
- **THEN** imprime pods y memoria esperados por nodo frente a 22 pods y a la memoria asignable, y termina con error si se supera cualquier presupuesto

#### Scenario: Presupuesto superado
- **WHEN** se sube a 2 el número de réplicas del frontend y de `products-service` y se añade un componente de 5 pods
- **THEN** el script falla porque quedan menos de 3 pods libres

#### Scenario: Regla documentada
- **WHEN** se lee `AGENTS.md`
- **THEN** indica el límite de 11 pods por nodo y la obligación de recalcular la capacidad
