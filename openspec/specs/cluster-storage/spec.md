# cluster-storage Specification

## Purpose
Driver EBS CSI con un rol IAM propio de permisos mínimos y StorageClass `gp3` por defecto para los volúmenes de PostgreSQL.

## Requirements

### Requirement: Driver EBS CSI con sus permisos

El clúster SHALL tener el addon administrado `aws-ebs-csi-driver`, con un rol IAM propio para su cuenta de servicio que incluya la política administrada del driver (`AmazonEBSCSIDriverPolicy`) y no use permisos amplios en los nodos. El controlador del driver SHALL ejecutarse con 1 réplica (`controller.replicaCount = 1` en `configuration_values` del addon) y CoreDNS también con 1 réplica (`replicaCount = 1`), para ahorrar pods y memoria en nodos pequeños.

#### Scenario: Addon instalado
- **WHEN** termina el `apply` y se ejecuta `aws eks list-addons --cluster-name <cluster>`
- **THEN** la lista incluye `aws-ebs-csi-driver`

#### Scenario: Permisos mínimos
- **WHEN** se revisa el rol del driver
- **THEN** solo puede ser asumido por la cuenta de servicio `ebs-csi-controller-sa` del namespace `kube-system` y tiene adjunta `AmazonEBSCSIDriverPolicy`

#### Scenario: Controlador con una réplica
- **WHEN** se ejecuta `kubectl get deploy ebs-csi-controller -n kube-system`
- **THEN** el Deployment tiene 1 réplica

#### Scenario: CoreDNS con una réplica
- **WHEN** se ejecuta `kubectl get deploy coredns -n kube-system`
- **THEN** el Deployment tiene 1 réplica

#### Scenario: Configuración válida
- **WHEN** se revisan los `configuration_values` de los addons
- **THEN** son JSON que cumple el esquema del addon (`aws eks describe-addon-configuration`)

### Requirement: StorageClass gp3 por defecto

El clúster SHALL tener una StorageClass llamada `gp3` con el aprovisionador `ebs.csi.aws.com`, tipo de volumen `gp3`, `volumeBindingMode: WaitForFirstConsumer` y expansión de volúmenes permitida, marcada como StorageClass por defecto. La StorageClass `gp2` que trae EKS SHALL dejar de ser la predeterminada. Se crea en la etapa `infra/terraform/argocd/`, porque necesita un clúster ya existente.

#### Scenario: StorageClass disponible
- **WHEN** se ejecuta `kubectl get storageclass` tras la etapa de Argo CD
- **THEN** `gp3` aparece como `(default)` con provisioner `ebs.csi.aws.com`

#### Scenario: gp2 deja de ser la predeterminada
- **WHEN** se ejecuta `kubectl get storageclass`
- **THEN** `gp2` no aparece como `(default)`

#### Scenario: PVC de PostgreSQL
- **WHEN** un StatefulSet pide un PVC con `storageClassName: gp3`
- **THEN** se aprovisiona un volumen EBS gp3 al programarse el pod
