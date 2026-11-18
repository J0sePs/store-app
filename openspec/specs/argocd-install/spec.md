# argocd-install Specification

## Purpose
Instalación de Argo CD en una etapa de Terraform separada, sin balanceador ni secretos en las salidas y sin manifiestos de la aplicación.

## Requirements

### Requirement: Etapa separada para Argo CD

Argo CD SHALL instalarse desde `infra/terraform/argocd/`, con su propio estado y proveedores (`helm` y `kubernetes`), que se configuran contra un clúster ya existente (identificado por `cluster_name` y la región). La etapa SHALL usar el chart oficial de `argo-cd` con la versión fijada por una variable y SHALL crear el namespace `argocd`.

#### Scenario: Orden de las etapas
- **WHEN** se sigue el README
- **THEN** primero se aplica `infra/terraform/` y después `infra/terraform/argocd/`

#### Scenario: Argo CD instalado
- **WHEN** termina el `apply` de la etapa y se ejecuta `kubectl get pods -n argocd`
- **THEN** los pods de Argo CD están en estado `Running`

#### Scenario: Versión fijada
- **WHEN** se revisa el `helm_release`
- **THEN** la versión del chart sale de una variable con valor por defecto explícito, no de `latest`

### Requirement: Exposición mínima y sin secretos

Argo CD SHALL quedar accesible dentro del clúster (Service `ClusterIP`) para no crear un balanceador adicional con costo; el acceso a la interfaz se hace con `kubectl port-forward`. La contraseña inicial de `admin` NO SHALL guardarse en git ni mostrarse en las salidas de Terraform: el README SHALL explicar cómo leerla del Secret `argocd-initial-admin-secret`.

#### Scenario: Sin balanceador
- **WHEN** se ejecuta `kubectl get svc -n argocd argocd-server`
- **THEN** el tipo es `ClusterIP`

#### Scenario: Contraseña fuera de las salidas
- **WHEN** se ejecuta `terraform output` en la etapa
- **THEN** no aparece ninguna contraseña ni token

### Requirement: Argo CD sincroniza el repositorio GitOps

La etapa SHALL dejar Argo CD listo para recibir la aplicación raíz (`root-app`) que se aplica a mano una sola vez desde `store-gitops`, sin que Terraform contenga manifiestos de la aplicación.

#### Scenario: Sin manifiestos de la aplicación
- **WHEN** se revisan los archivos de `infra/terraform/argocd/`
- **THEN** no hay Deployments, Services ni Applications del proyecto

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
