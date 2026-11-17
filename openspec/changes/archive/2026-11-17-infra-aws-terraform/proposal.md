## Why

Los tres componentes ya funcionan en local con `docker compose`. Para desplegarlos con GitOps hace falta la infraestructura en AWS: red, clúster EKS, repositorios de imágenes, almacenamiento para las bases de datos, acceso seguro de GitHub Actions y Argo CD. Se define ahora como código para poder crearla y destruirla de forma repetible y barata (es un proyecto académico, con costo por hora).

## What Changes

- Crear `infra/terraform/` (región `us-east-1`) con los módulos oficiales `terraform-aws-modules`:
  - **VPC** con un solo NAT gateway.
  - **EKS** con un grupo de nodos administrado (2 × t3.medium).
  - **3 repos ECR** (`frontend`, `products-service`, `orders-service`) con escaneo al subir y política de ciclo de vida que conserva las últimas 10 imágenes.
  - **Addon EBS CSI** con su rol IAM.
  - **Proveedor OIDC de GitHub** y un rol IAM que solo puede asumir `<usuario>/store-app` en la rama `main`, con permiso de push a esos 3 ECR (sin llaves estáticas).
- Etapa separada `infra/terraform/argocd/`: instala Argo CD con `helm_release` y crea la StorageClass `gp3` (por defecto) en el clúster.
- `variables.tf`, `outputs.tf` (nombre del clúster, URLs de ECR, ARN del rol) y `terraform.tfvars.example`; `default_tags` con `Project = "store"`.
- `README.md` en español: pasos de apply y destroy, costo estimado por hora y advertencia de borrar los Services `LoadBalancer` antes del destroy.
- Alcance de esta sesión: solo generar código y ejecutar `terraform fmt` y `terraform validate`. **No se ejecuta `apply`**, `destroy` ni `plan` contra AWS.

Supuestos (detallados en el design): estado local ignorado por git; el usuario de GitHub se pasa por variable; Kubernetes 1.36; el endpoint público del clúster se restringe por CIDR configurable.

No hay cambios **BREAKING**.

## Capabilities

### New Capabilities

- `eks-cluster`: red (VPC) y clúster EKS con nodos administrados y acceso para quien lo crea.
- `container-registry`: repositorios ECR con escaneo y ciclo de vida.
- `cluster-storage`: driver EBS CSI con sus permisos y StorageClass `gp3`.
- `github-oidc-access`: proveedor OIDC de GitHub y rol de CI limitado a un repositorio y rama.
- `argocd-install`: etapa separada que instala Argo CD.
- `infra-conventions`: variables, salidas, etiquetas, secretos fuera de git y documentación operativa.

### Modified Capabilities

Ninguna.

## Impact

- **Componente afectado:** `infra/terraform/` y `infra/terraform/argocd/` (nuevos). No cambia el código de los servicios.
- **Proveedores y módulos:** `aws`, `helm`, `kubernetes`; módulos `vpc`, `eks`, `ecr` e `iam` de `terraform-aws-modules`.
- **Costo real al hacer `apply`:** aproximadamente 0,25 USD/hora más balanceadores; se detalla en el README.
- **Fuera de alcance:** manifiestos GitOps (`gitops-manifests`), CI (`ci-github-actions`), backend remoto del estado, dominio y HTTPS.
- **Archivos del repo:** `.gitignore` (verificar), `feature_list.json` y `progress.md`.
