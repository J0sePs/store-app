# Tasks

> Reglas de este change: no se ejecuta `terraform apply` ni `destroy` (el `apply` lo ejecuta el usuario en su terminal); solo `terraform fmt`, `validate` y `plan`, que son de lectura. Si el plan muestra un destroy o replace del clúster, la VPC, el NAT o las subredes, **se detiene todo y se avisa**. Los cambios de `../store-gitops` quedan en commit local, sin `git push`. Los de `store-app` quedan sin commit.

## 1. Estado y herramientas

- [x] 1.1 Añadir `infra-free-tier-nodes` a `feature_list.json` como `change-8` (dependencias `change-4` y `change-5`) con estado `in_progress`; verificar con `./init.sh` que solo hay un change activo y que `demo-visible-change` sigue `pending`
- [x] 1.2 Compilar `helm` v3 (versión fijada) con `go install` en el directorio temporal del agente y descargar el chart `argo-cd` 10.17.2 en un directorio propio; verificar con `helm version` y `ls` del chart

## 2. Nodos y addons en Terraform

- [x] 2.1 Cambiar `node_instance_types` a `["t3.small"]` en `variables.tf` (descripción con la restricción del plan Gratuito y cómo volver a `t3.medium`) y comentar el ejemplo en `terraform.tfvars.example`; verificar con `terraform fmt -check` y `terraform validate`
- [x] 2.2 Añadir `configuration_values` con `replicaCount = 1` a `coredns` (mapa `addons` de `eks.tf`) y con `controller.replicaCount = 1` al `aws_eks_addon.ebs_csi` (`ebs-csi.tf`); verificar con `terraform validate` y comprobando que las claves existen en el esquema del addon con `aws eks describe-addon-configuration` (solo lectura)

## 3. Argo CD con huella reducida

- [x] 3.1 Crear `infra/terraform/argocd/values.yaml` (`dex.enabled: false`, `notifications.enabled: false`, `applicationSet.replicas: 0`, 1 réplica y los recursos de la tabla del design) y cargarlo con `file()` en el `helm_release`; verificar con `terraform fmt -check` y `terraform validate` en esa carpeta, y con un script de Python que todas las claves existen en el `values.yaml` del chart 10.17.2
- [x] 3.2 Renderizar con `helm template` usando esos valores; verificar que hay exactamente 4 Deployments o StatefulSets de larga vida con réplicas mayores que 0 (controlador, repo-server, server y redis), que no existen los de `dex` ni `notifications`, que el de ApplicationSet tiene 0 réplicas y que los 4 contenedores tienen `requests` y `limits`

## 4. Aplicación en store-gitops

- [x] 4.1 Editar `apps/frontend`, `apps/products-service` y `apps/orders-service` (1 réplica, estrategia con `maxSurge: 1` y `maxUnavailable: 0`, recursos de la tabla del design); verificar con `kubectl kustomize` de los tres y con un script de Python que lee réplicas, estrategia y recursos
- [x] 4.2 Editar `apps/products-db` y `apps/orders-db` (`requests` 50m/128Mi, `limits` 300m/256Mi y `args: ["postgres", "-c", "shared_buffers=32MB", "-c", "max_connections=20"]`); verificar con `kubectl kustomize` y probando PostgreSQL en Docker con `--memory=256m`, uid 70 y `--cap-drop ALL`: arranca, atiende una carga de inserciones y consultas, su uso queda por debajo de 256MiB y `docker inspect` da `OOMKilled=false`
- [x] 4.3 Medir el consumo real de memoria de los contenedores de la aplicación con `docker compose` y `docker stats` (reposo y tras unas peticiones); verificar que `products-service`, `orders-service` y el frontend quedan por debajo de sus límites (192Mi, 64Mi y 64Mi) con margen, y ajustar los límites en los manifiestos si no es así, antes de seguir
- [x] 4.4 Hacer commit **local** en `../store-gitops` con los cambios de este grupo (sin `git push`); verificar con `git -C ../store-gitops log --oneline -2` y `git -C ../store-gitops status -sb` (adelantada de `origin/main` y árbol limpio)

## 5. Presupuesto de capacidad

- [x] 5.1 Escribir `scripts/check-capacity.py` (manifiestos de `store-gitops` vía `kubectl kustomize`, Argo CD vía `helm template`, constantes documentadas de los addons; imprime pods y memoria esperados por nodo frente a 22 pods y 2 868 MiB; sale con error si quedan menos de 3 pods libres o los `requests` superan el 70 %); verificar con `python -m py_compile`, `ruff check` y una ejecución que termina con código 0
- [x] 5.2 Probar que el script falla con presupuestos inválidos: copia temporal con 2 réplicas en frontend y `products-service` y un componente de 5 pods extra, y otra con un `request` de memoria inflado; verificar que ambos casos terminan con error y un mensaje claro
- [x] 5.3 Ejecutar el script sobre el estado real y guardar la tabla (pods por nodo frente a 2 × 11 con al menos 3 libres, y memoria solicitada frente a la asignable) para mostrarla al usuario; verificar que coincide con la del design (17 pods, 5 libres, ≈ 1 350 MiB)

## 6. Documentación

- [x] 6.1 Actualizar `openspec/config.yaml` (2 × t3.small por el plan Gratuito, límite de pods y regla de capacidad) y corregir el error de YAML de `rules.specs[1]`; verificar con `openspec context --json` y `openspec status` sin el aviso "Rules for 'specs' must be an array of strings"
- [x] 6.2 Añadir a `AGENTS.md` la regla de capacidad (2 × t3.small, 11 pods por nodo, 1 réplica por Deployment y recalcular con `scripts/check-capacity.py` antes de añadir pods) y el script en la estructura; verificar con `grep`
- [x] 6.3 Actualizar `infra/terraform/README.md` (tipo de nodo, tabla de costos, nota del plan Gratuito y cómo usar `t3.medium` en cuenta de pago, tabla de capacidad, sección de problemas) y el README de `../store-gitops` (1 réplica por Deployment, recursos y capacidad); verificar con `grep` que `t3.medium` solo aparece como alternativa de cuenta de pago y que los comandos documentados siguen siendo válidos

## 7. Plan de Terraform

- [x] 7.1 Ejecutar `terraform plan -input=false -out=plan.tfplan` en `infra/terraform` (con el `terraform.tfvars` actual) y comprobar con `git check-ignore` que `plan.tfplan` está ignorado; verificar que termina con código 0
- [x] 7.2 Analizar `terraform show -json plan.tfplan` y clasificar las acciones por recurso; **verificar que no hay `delete` ni `replace` de `aws_eks_cluster`, `aws_vpc`, `aws_nat_gateway`, `aws_subnet` ni `aws_internet_gateway`**. Si aparece alguno, detenerse y avisar al usuario sin continuar. Esperado: reemplazo del grupo de nodos y creación de `coredns`, `kube-proxy` y `aws-ebs-csi-driver` con su configuración, más lo que quedó pendiente del `apply` parcial
- [x] 7.3 Resumir el plan para el usuario (recursos por acción, tipo de instancia y `configuration_values` de los addons) y recordar que el `apply` lo ejecuta él; verificar que el resumen incluye el costo por hora actualizado

## 8. Cierre

- [x] 8.1 Ejecutar `./init.sh` y `openspec validate infra-free-tier-nodes`; verificar que ambos terminan sin errores y que `terraform fmt -check -recursive` y `terraform validate` pasan en las dos etapas
- [x] 8.2 Actualizar `feature_list.json` (`change-8` en `done`, con la evidencia y la aclaración de que el `apply` lo ejecuta el usuario) y `progress.md` (paso 3 del despliegue: el `apply` parcial falló por el plan Gratuito; qué cambia este change; plan listo; siguiente paso: el usuario aplica y luego se retoma desde el paso 4); verificar que `demo-visible-change` sigue `pending`

## Workflow follow-up

- El usuario ejecuta `terraform apply plan.tfplan` en `infra/terraform`.
- Archivar con `/openspec-archive-change` después de confirmar que los nodos están `Ready`.
- `git push` de `store-gitops` y de `store-app` solo con confirmación.
