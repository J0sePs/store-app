## MODIFIED Requirements

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
