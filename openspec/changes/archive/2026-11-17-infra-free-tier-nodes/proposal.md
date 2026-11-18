## Why

El `terraform apply` del despliegue v1 falló al crear el grupo de nodos: la cuenta de AWS está en el **plan Gratuito** (`accountPlanType: FREE`, 129,60 USD de crédito) y ese plan solo permite instancias elegibles para la capa gratuita; `t3.medium` no lo es (`InvalidParameterCombination … not eligible for Free Tier`). El clúster y la VPC ya existen (parcialmente aplicados) y cuestan ≈ 0,16 USD/h sin nodos. Hay que hacer que todo el sistema corra en **2 × t3.small**, que sí es elegible, y cuyos límites son estrictos: 11 pods y ≈ 1,4 GiB asignables por nodo.

## What Changes

- **Nodos:** `node_instance_types = ["t3.small"]`, con 2 nodos fijos (mínimo, deseado y máximo en 2).
- **Addons de EKS** con `configuration_values`: `coredns` con 1 réplica y `aws-ebs-csi-driver` con el controlador en 1 réplica.
- **Argo CD** (`infra/terraform/argocd`): `dex` y `notifications` desactivados, `applicationSet` con 0 réplicas (el chart no trae un `enabled`), 1 réplica en cada componente y `requests`/`limits` pequeños.
- **Aplicación** (`../store-gitops`): 1 réplica por Deployment (el frontend baja de 2 a 1), `RollingUpdate` con `maxSurge: 1` y `maxUnavailable: 0`, y `requests` de memoria ajustados: PostgreSQL 128Mi, `products-service` 96Mi, `orders-service` 32Mi y frontend 32Mi. PostgreSQL arranca con `shared_buffers` y `max_connections` reducidos para caber en ese presupuesto.
- **Presupuesto de capacidad:** tabla de pods y memoria esperados por nodo frente a 2 × 11 = 22 pods, con al menos 3 libres para el rolling update de la demo, calculada con un script y documentada.
- **Documentación:** `openspec/config.yaml` (también se corrige su error de YAML en `rules.specs`), `AGENTS.md`, `infra/terraform/README.md`, el README de `store-gitops` y el costo por hora.
- **Plan de Terraform:** al final se genera `terraform plan -out=plan.tfplan` y se resume. Debe cambiar **solo** el grupo de nodos y los addons (más lo que quedó pendiente del `apply` parcial), **sin recrear el clúster ni la VPC**; si aparece un destroy o replace de ellos, se detiene todo. El `terraform apply` lo ejecuta el usuario.

Los cambios de `../store-gitops` quedan en **commit local, sin push**.

No hay cambios **BREAKING**.

## Capabilities

### New Capabilities

- `cluster-capacity`: presupuesto de pods y de memoria del clúster de 2 × t3.small y cómo se comprueba.

### Modified Capabilities

- `eks-cluster`: el grupo de nodos por defecto pasa a `t3.small`.
- `cluster-storage`: el controlador del driver EBS CSI y CoreDNS con una réplica.
- `argocd-install`: instalación con huella reducida.
- `k8s-workloads`: una réplica por Deployment y nuevos `requests`/`limits`.
- `k8s-databases`: ajuste de memoria de PostgreSQL.

## Impact

- **Componentes afectados:** `infra/terraform/` y `infra/terraform/argocd/` (código, sin apply), `../store-gitops/apps/*`, y documentación.
- **Estado real de AWS:** no se modifica durante este change; solo se genera el plan.
- **Costo estimado:** ≈ 0,20 USD/h sin balanceadores (antes 0,24) y ≈ 0,23 con el del frontend (≈ 5,5 USD/día); con el crédito de 129,60 USD alcanza para más de 20 días.
- **Fuera de alcance:** subir de plan de AWS, prefix delegation del CNI y cambiar de tipo de instancia.
- **Riesgos:** t3.small tiene CPU con créditos (burstable) y poca memoria; se mide el uso real de los contenedores antes de fijar límites.
