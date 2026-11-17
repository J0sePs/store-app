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
