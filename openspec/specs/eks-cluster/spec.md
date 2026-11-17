# eks-cluster Specification

## Purpose
Red VPC económica (un solo NAT) y clúster EKS con nodos administrados, acceso de administrador para quien lo crea y endpoint público limitable por CIDR.

## Requirements

### Requirement: Red VPC económica

La infraestructura SHALL crear una VPC en la región configurada (por defecto `us-east-1`) con subredes públicas y privadas en al menos 2 zonas de disponibilidad y un único NAT gateway compartido. Las subredes SHALL llevar las etiquetas de Kubernetes que permiten crear balanceadores (`kubernetes.io/role/elb` en las públicas y `kubernetes.io/role/internal-elb` en las privadas).

#### Scenario: Un solo NAT
- **WHEN** se revisa la configuración de la VPC
- **THEN** el NAT gateway es único (`single_nat_gateway` activo) y los nodos usan subredes privadas

#### Scenario: Etiquetas de balanceador
- **WHEN** se revisan las subredes
- **THEN** las públicas tienen `kubernetes.io/role/elb = 1` y las privadas `kubernetes.io/role/internal-elb = 1`

### Requirement: Clúster EKS con nodos administrados

La infraestructura SHALL crear un clúster EKS con el módulo oficial `terraform-aws-modules/eks/aws`, en las subredes privadas, con un grupo de nodos administrado de 2 instancias `t3.medium` por defecto (tipo y tamaños configurables por variables). La versión de Kubernetes SHALL ser una variable con un valor por defecto soportado por EKS. Quien crea el clúster SHALL recibir permisos de administrador mediante una entrada de acceso, para poder usar `kubectl`. El acceso público al endpoint SHALL poder limitarse con una lista de CIDR.

#### Scenario: Nodos por defecto
- **WHEN** se aplican las variables por defecto
- **THEN** el grupo de nodos solicita 2 instancias `t3.medium` en subredes privadas

#### Scenario: Acceso del creador
- **WHEN** termina el `apply`
- **THEN** el usuario que lo ejecutó puede ejecutar `kubectl get nodes` tras `aws eks update-kubeconfig`

#### Scenario: Endpoint restringido
- **WHEN** `cluster_endpoint_public_access_cidrs` se define como `["203.0.113.4/32"]`
- **THEN** el endpoint público del clúster solo acepta esa dirección

### Requirement: Validación sin aplicar

El código SHALL formatearse con `terraform fmt -recursive` y validarse con `terraform validate` sin errores, sin necesidad de crear recursos.

#### Scenario: Formato y validación
- **WHEN** se ejecuta `terraform fmt -check -recursive` y `terraform validate` en `infra/terraform/`
- **THEN** ambos terminan sin errores
