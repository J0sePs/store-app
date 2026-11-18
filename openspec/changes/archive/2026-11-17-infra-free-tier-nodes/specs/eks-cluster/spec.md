## MODIFIED Requirements

### Requirement: Clúster EKS con nodos administrados

La infraestructura SHALL crear un clúster EKS con el módulo oficial `terraform-aws-modules/eks/aws`, en las subredes privadas, con un grupo de nodos administrado de 2 instancias `t3.small` por defecto, con tamaño mínimo, deseado y máximo iguales a 2 (tipo y tamaños configurables por variables). El tipo por defecto SHALL ser elegible para el plan Gratuito de AWS, que solo permite instancias de la capa gratuita. La versión de Kubernetes SHALL ser una variable con un valor por defecto soportado por EKS. Quien crea el clúster SHALL recibir permisos de administrador mediante una entrada de acceso, para poder usar `kubectl`. El acceso público al endpoint SHALL poder limitarse con una lista de CIDR.

#### Scenario: Nodos por defecto
- **WHEN** se aplican las variables por defecto
- **THEN** el grupo de nodos solicita 2 instancias `t3.small` en subredes privadas, con mínimo, deseado y máximo iguales a 2

#### Scenario: Plan Gratuito de AWS
- **WHEN** la cuenta está en el plan Gratuito y se aplican las variables por defecto
- **THEN** las instancias se lanzan sin el error `not eligible for Free Tier`

#### Scenario: Cuenta de pago
- **WHEN** `node_instance_types` se define como `["t3.medium"]` en una cuenta de pago
- **THEN** el grupo de nodos usa `t3.medium` sin otros cambios de código

#### Scenario: Acceso del creador
- **WHEN** termina el `apply`
- **THEN** el usuario que lo ejecutó puede ejecutar `kubectl get nodes` tras `aws eks update-kubeconfig`

#### Scenario: Endpoint restringido
- **WHEN** `cluster_endpoint_public_access_cidrs` se define como `["203.0.113.4/32"]`
- **THEN** el endpoint público del clúster solo acepta esa dirección

#### Scenario: Cambio de tipo sin recrear el clúster
- **WHEN** se cambia el tipo de instancia y se ejecuta `terraform plan` sobre el clúster ya creado
- **THEN** el plan reemplaza el grupo de nodos y no destruye ni reemplaza el clúster ni la VPC
