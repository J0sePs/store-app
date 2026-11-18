# infra/terraform

Infraestructura de `store-app` en AWS (región `us-east-1`), en **dos etapas** con estado independiente:

| Etapa | Carpeta | Qué crea |
|---|---|---|
| 1 | `infra/terraform/` | VPC (2 zonas, 1 NAT), clúster EKS (2 × t3.small), 3 repositorios ECR, addon EBS CSI con su rol IAM, proveedor OIDC de GitHub y el rol de CI |
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
| 2 nodos `t3.small` (0,0208 cada uno) | 0,042 |
| NAT gateway (sin contar tráfico, 0,045/GB) | 0,045 |
| IPv4 pública del NAT | 0,005 |
| Volúmenes EBS gp3 (nodos y 2 bases de datos), KMS y logs | 0,007 |
| **Subtotal sin balanceadores** | **≈ 0,20** |
| Cada Service `LoadBalancer` (balanceador + IPv4 públicas) | ≈ 0,03 |
| **Total con el balanceador del frontend** | **≈ 0,23 (≈ 5,5 USD al día)** |

ECR cobra por almacenamiento (centavos con la política de 10 imágenes). Argo CD no añade costo si se accede por `port-forward`.

> **Plan Gratuito de AWS:** una cuenta en el plan Gratuito (`aws freetier get-account-plan-state`) solo puede lanzar instancias elegibles para la capa gratuita y consume crédito (por ejemplo, 129,60 USD ≈ 23 días encendido a 0,23 USD/h). Por eso los nodos son `t3.small`: con `t3.medium` el grupo de nodos falla con `InvalidParameterCombination … not eligible for Free Tier`. En una cuenta de pago puedes volver a nodos más grandes con `node_instance_types = ["t3.medium"]` en `terraform.tfvars`.

## Capacidad del clúster (2 × t3.small)

Cada `t3.small` admite como máximo **11 pods** y ofrece ≈ **1,4 GiB** de memoria asignable (22 pods y ≈ 2,8 GiB en total). Para que todo quepa:

- Una réplica por Deployment de la aplicación, una por CoreDNS y por el controlador del driver EBS CSI (`configuration_values` de los addons) y 4 pods de Argo CD (controlador, repo-server, server y redis; `dex`, `notifications` y el controlador de ApplicationSet desactivados en `argocd/values.yaml`).
- `requests` de memoria ajustados: PostgreSQL 128Mi (con `shared_buffers=32MB` y `max_connections=20`), `products-service` 96Mi, `orders-service` 32Mi y frontend 32Mi.

| Grupo | Pods | Memoria solicitada |
|---|---|---|
| DaemonSets (`aws-node`, `kube-proxy`, `ebs-csi-node`, uno por nodo) | 6 | 208 MiB |
| kube-system (`coredns`, `ebs-csi-controller`) | 2 | 302 MiB |
| Argo CD | 4 | 384 MiB |
| Aplicación (frontend, 2 servicios, 2 bases de datos) | 5 | 416 MiB |
| **Total** | **17 de 22 (5 libres)** | **1 310 MiB de ≈ 2 866 (46 %)** |

Con el rolling update de la demo (frontend y `products-service` a la vez) hay 2 pods extra y quedan 3 libres, que es el mínimo. Los valores de DaemonSets y addons son los medidos en el clúster real tras el `apply` (`kubectl get pods -n kube-system`); cada nodo `t3.small` ofrece 11 pods, 1930m de CPU y ≈ 1 433 MiB asignables.

**Antes de añadir pods, réplicas o subir `requests` de memoria**, recalcula el presupuesto (necesita `kubectl` y PyYAML; el repositorio `store-gitops` debe estar en `../store-gitops`):

```bash
products-service/.venv/bin/python scripts/check-capacity.py
```

Imprime los pods y la memoria por grupo y por nodo, y termina con error si quedan menos de 3 pods libres o si los `requests` superan el 70 % de la memoria asignable.

## Pasos de `apply`

### 1. Etapa principal

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # git lo ignora
# edita terraform.tfvars: pon tu usuario en github_owner, los ids de GitHub (ver "Ids de GitHub para el rol de CI") y, si quieres, tu IP en cluster_endpoint_public_access_cidrs
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

Argo CD se instala con 4 pods (controlador, repo-server, server y redis); sus valores y recursos están en `infra/terraform/argocd/values.yaml` (ver "Capacidad del clúster").

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
| `github_owner_id`, `github_repository_id` | `null` | Ids numéricos de GitHub, **los dos o ninguno**. Obligatorios si el repositorio usa el sujeto inmutable (ver más abajo) |
| `github_repository` / `github_branch` | `store-app` / `main` | Único repositorio y rama que pueden asumir el rol de CI |
| `cluster_name` | `store-eks` | Nombre del clúster (la etapa 2 usa el mismo) |
| `kubernetes_version` | `1.36` | Versión de Kubernetes (EKS soporta 1.34 a 1.37) |
| `node_instance_types`, `node_min_size`, `node_desired_size`, `node_max_size` | `t3.small`, 2, 2, 2 | Nodos del clúster (`t3.small` por el plan Gratuito) |
| `cluster_endpoint_public_access_cidrs` | `["0.0.0.0/0"]` | Quién puede llegar al endpoint público; limítalo a tu IP |
| `ecr_repository_names` | `frontend`, `products-service`, `orders-service` | Repositorios ECR |
| `ecr_keep_last_images` | `10` | Imágenes que se conservan por repositorio |
| `create_github_oidc_provider` | `true` | Poner `false` si la cuenta ya tiene el proveedor |

Salidas de la etapa 1: `cluster_name`, `region`, `ecr_repository_urls`, `github_actions_role_arn` y `update_kubeconfig_command`.

## Seguridad

- **Sin llaves estáticas:** GitHub Actions asume el rol por OIDC. La política de confianza exige un único sujeto exacto (sin comodines), así que otra rama u otro repositorio no pueden asumirlo: con los ids definidos es `repo:<github_owner>@<github_owner_id>/<github_repository>@<github_repository_id>:ref:refs/heads/<github_branch>` (sujeto inmutable de GitHub) y sin ellos `repo:<github_owner>/<github_repository>:ref:refs/heads/<github_branch>`. La salida `github_actions_subject` muestra el que quedó configurado.
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

## Ids de GitHub para el rol de CI

GitHub puede emitir el `sub` del token OIDC con los **ids numéricos** del dueño y del repositorio (*sujeto inmutable*, activado por defecto en repositorios nuevos). Si la política de confianza del rol espera el formato antiguo, el login falla con `Not authorized to perform sts:AssumeRoleWithWebIdentity`. Comprueba qué formato usa tu repositorio y obtén los ids:

```bash
gh api repos/<USUARIO>/store-app/actions/oidc/customization/sub      # use_immutable_subject y sub_claim_prefix
gh api repos/<USUARIO>/store-app --jq '.id, .owner.id'               # primero el id del repositorio y luego el del dueño
```

Si `use_immutable_subject` es `true`, define en `terraform.tfvars` los dos ids (`github_repository_id` con el primer número y `github_owner_id` con el segundo) y aplica. Con los ids, un repositorio renombrado, transferido o recreado con el mismo nombre no hereda el acceso. El valor que acepta el rol se ve con `terraform output github_actions_subject`.

## Problemas frecuentes

- **`Not authorized to perform sts:AssumeRoleWithWebIdentity` en `configure-aws-credentials` (GitHub Actions):** el `sub` del token no coincide con la política de confianza del rol. Lo más probable es el sujeto inmutable: define `github_owner_id` y `github_repository_id` (ver "Ids de GitHub para el rol de CI"). Si no, revisa que `AWS_ROLE_ARN` sea idéntica a `terraform output github_actions_role_arn`, que el workflow corra en la rama `main` y que `github_owner` y `github_repository` coincidan con el repositorio.
- **`EntityAlreadyExists` al crear el proveedor OIDC:** ya existe en la cuenta; usa `create_github_oidc_provider = false`.
- **El grupo de nodos falla con `not eligible for Free Tier`:** la cuenta está en el plan Gratuito y el tipo de instancia no es elegible. Usa `t3.small` (el valor por defecto) u otro tipo de la lista de `aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true`, o pasa la cuenta a un plan de pago.
- **Pods en `Pending` por falta de capacidad:** 2 nodos `t3.small` admiten 22 pods en total (ver "Capacidad del clúster"). Ejecuta `scripts/check-capacity.py` para ver qué grupo ocupa más; si de verdad necesitas más, sube `node_desired_size` y `node_max_size`, o usa un tipo con más pods.
- **Fallo del `apply` de la etapa 2 con "cluster not found":** aplica primero la etapa 1 y comprueba que `cluster_name` coincide en ambas.
- **`kubectl` sin permisos:** el clúster da permisos de administrador solo a quien ejecutó el `apply`; usa la misma identidad de AWS.
