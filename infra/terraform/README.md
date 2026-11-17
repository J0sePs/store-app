# infra/terraform

Infraestructura de `store-app` en AWS (región `us-east-1`), en **dos etapas** con estado independiente:

| Etapa | Carpeta | Qué crea |
|---|---|---|
| 1 | `infra/terraform/` | VPC (2 zonas, 1 NAT), clúster EKS (2 × t3.medium), 3 repositorios ECR, addon EBS CSI con su rol IAM, proveedor OIDC de GitHub y el rol de CI |
| 2 | `infra/terraform/argocd/` | Argo CD (`helm_release`) y la StorageClass `gp3` por defecto |

> **`terraform apply` y `terraform destroy` los ejecutas tú.** Crean y borran recursos que cuestan dinero. Ningún agente de IA debe ejecutarlos sin tu confirmación (regla de `AGENTS.md`). `terraform fmt` y `terraform validate` se pueden correr libremente.

## Requisitos

- Terraform `>= 1.10`, AWS CLI v2 y `kubectl`.
- Credenciales de AWS con permisos para crear VPC, EKS, IAM y ECR. Comprueba la cuenta antes de seguir:
  ```bash
  aws sts get-caller-identity
  ```
- Si tu cuenta **ya tiene** el proveedor OIDC de GitHub (`token.actions.githubusercontent.com`), pon `create_github_oidc_provider = false` (AWS admite uno solo por cuenta).

## Verificación sin crear nada

```bash
cd infra/terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate

cd argocd
terraform init -backend=false
terraform validate
```

## Costo estimado

Valores aproximados de lista en `us-east-1` (verifícalos en la [calculadora de AWS](https://calculator.aws/)). **Se cobra por hora mientras exista el clúster.**

| Componente | USD/hora aprox. |
|---|---|
| Plano de control de EKS | 0,100 |
| 2 nodos `t3.medium` (0,0416 cada uno) | 0,083 |
| NAT gateway (sin contar tráfico, 0,045/GB) | 0,045 |
| IPv4 pública del NAT | 0,005 |
| Volúmenes EBS gp3 (nodos y 2 bases de datos) | 0,006 |
| **Subtotal sin balanceadores** | **≈ 0,24** |
| Cada Service `LoadBalancer` (balanceador + IPv4 públicas) | ≈ 0,03 |
| **Total con el balanceador del frontend** | **≈ 0,27 (≈ 6,5 USD al día)** |

ECR cobra por almacenamiento (centavos con la política de 10 imágenes). Argo CD no añade costo si se accede por `port-forward`.

## Pasos de `apply`

### 1. Etapa principal

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # git lo ignora
# edita terraform.tfvars: pon tu usuario en github_owner (y, si quieres, tu IP en cluster_endpoint_public_access_cidrs)
terraform init
terraform plan
terraform apply          # tarda unos 15-20 minutos
```

Anota las salidas (`terraform output`): `cluster_name`, `ecr_repository_urls` y `github_actions_role_arn` (esta última va a la variable `AWS_ROLE_ARN` de GitHub).

### 2. Conectar `kubectl`

```bash
aws eks update-kubeconfig --name store-eks --region us-east-1
kubectl get nodes        # deben verse 2 nodos Ready
```

### 3. Etapa de Argo CD y StorageClass

```bash
cd argocd
cp terraform.tfvars.example terraform.tfvars   # git lo ignora
terraform init
terraform plan
terraform apply
kubectl get pods -n argocd
kubectl get storageclass          # gp3 debe aparecer como (default)
```

Abrir la interfaz de Argo CD:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
kubectl port-forward svc/argocd-server -n argocd 8080:443    # https://localhost:8080, usuario admin
```

La contraseña no se guarda en git ni en las salidas de Terraform.

### 4. Pasos fuera de Terraform

Los hace el change `gitops-manifests` y la CI (ver `docs/prompts.md`, sección "Despliegue en AWS"): crear los secrets de las bases de datos en el namespace `store`, aplicar la `root-app` de `../store-gitops` una sola vez y configurar en GitHub el secret `GITOPS_TOKEN` y la variable `AWS_ROLE_ARN`.

## Variables principales

| Variable | Por defecto | Descripción |
|---|---|---|
| `github_owner` | *(obligatoria)* | Usuario u organización de GitHub dueño de `store-app` |
| `github_repository` / `github_branch` | `store-app` / `main` | Único repositorio y rama que pueden asumir el rol de CI |
| `cluster_name` | `store-eks` | Nombre del clúster (la etapa 2 usa el mismo) |
| `kubernetes_version` | `1.36` | Versión de Kubernetes (EKS soporta 1.34 a 1.37) |
| `node_instance_types`, `node_min_size`, `node_desired_size`, `node_max_size` | `t3.medium`, 2, 2, 2 | Nodos del clúster |
| `cluster_endpoint_public_access_cidrs` | `["0.0.0.0/0"]` | Quién puede llegar al endpoint público; limítalo a tu IP |
| `ecr_repository_names` | `frontend`, `products-service`, `orders-service` | Repositorios ECR |
| `ecr_keep_last_images` | `10` | Imágenes que se conservan por repositorio |
| `create_github_oidc_provider` | `true` | Poner `false` si la cuenta ya tiene el proveedor |

Salidas de la etapa 1: `cluster_name`, `region`, `ecr_repository_urls`, `github_actions_role_arn` y `update_kubeconfig_command`.

## Seguridad

- **Sin llaves estáticas:** GitHub Actions asume el rol por OIDC. La política de confianza exige el sujeto exacto `repo:<github_owner>/<github_repository>:ref:refs/heads/<github_branch>` (sin comodines), así que otra rama u otro repositorio no pueden asumirlo.
- El rol solo puede iniciar sesión en ECR y subir o consultar imágenes de **los tres repositorios**. No tiene permisos sobre EKS ni IAM.
- El estado es **local** (`terraform.tfstate`) y está ignorado por git. Contiene datos de tu cuenta: no lo borres mientras exista la infraestructura (te quedarías con recursos huérfanos que siguen cobrando) y no lo subas. Un backend remoto (S3) queda para más adelante.
- Los repositorios ECR aceptan etiquetas mutables para que CI pueda repetir una subida con el mismo SHA; la etiqueta `latest` está prohibida y se controla en CI.
- `.terraform.lock.hcl` **sí** se versiona (fija las versiones de los proveedores); `terraform.tfvars`, `*.tfstate*` y `.terraform/` no.

## Pasos de `destroy` (en orden inverso)

> ## ⚠️ Antes de `destroy`: borra los Services `LoadBalancer` y los PVC
>
> Los Services de tipo `LoadBalancer` crean balanceadores en AWS y los PVC crean volúmenes EBS **fuera de Terraform**. Si haces `terraform destroy` sin borrarlos, esos recursos quedan huérfanos: el balanceador mantiene interfaces de red dentro de la VPC y **el borrado de la VPC falla** (`DependencyViolation`), y ambos **siguen cobrando**.

### 1. Borrar lo que Kubernetes creó en AWS

```bash
# Detén Argo CD para que no vuelva a crear lo que borres
kubectl delete applications --all -n argocd

# Borra los Services LoadBalancer y los PVC (y espera a que desaparezcan)
kubectl get svc -A | grep LoadBalancer
kubectl delete svc --all -n store
kubectl delete pvc --all -n store

# Comprueba (solo lectura) que no quedan balanceadores ni volúmenes
aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[].LoadBalancerName'
aws elb describe-load-balancers --region us-east-1 --query 'LoadBalancerDescriptions[].LoadBalancerName'
aws ec2 describe-volumes --region us-east-1 --filters Name=status,Values=available --query 'Volumes[].VolumeId'
```

### 2. Etapa de Argo CD

```bash
cd infra/terraform/argocd
terraform destroy
```

### 3. Etapa principal

```bash
cd infra/terraform
terraform destroy       # los repositorios ECR se borran aunque tengan imágenes
```

### 4. Comprobar que no queda nada cobrando

```bash
aws eks list-clusters --region us-east-1
aws ec2 describe-nat-gateways --region us-east-1 --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
aws ec2 describe-addresses --region us-east-1 --query 'Addresses[].PublicIp'
```

## Problemas frecuentes

- **`EntityAlreadyExists` al crear el proveedor OIDC:** ya existe en la cuenta; usa `create_github_oidc_provider = false`.
- **Pods en `Pending` por falta de capacidad:** 2 nodos `t3.medium` admiten unos 34 pods en total; sube `node_desired_size` y `node_max_size` o cambia `node_instance_types`.
- **Fallo del `apply` de la etapa 2 con "cluster not found":** aplica primero la etapa 1 y comprueba que `cluster_name` coincide en ambas.
- **`kubectl` sin permisos:** el clúster da permisos de administrador solo a quien ejecutó el `apply`; usa la misma identidad de AWS.
