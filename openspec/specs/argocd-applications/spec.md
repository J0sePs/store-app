# argocd-applications Specification

## Purpose
Application raíz (app-of-apps) y una Application por componente en Argo CD, con sincronización automática, prune y selfHeal.

## Requirements

### Requirement: Application raíz (app-of-apps)

`store-gitops` SHALL incluir `argocd/root-app.yaml`, una Application de Argo CD (namespace `argocd`) que sincroniza la carpeta `argocd/apps` del repositorio `https://github.com/J0sePs/store-gitops.git`, rama `main`, con sincronización automática, `prune` y `selfHeal`. SHALL aplicarse a mano una sola vez con `kubectl apply -f argocd/root-app.yaml`; a partir de ahí todo se gestiona desde git.

#### Scenario: Raíz sincroniza las Applications
- **WHEN** se aplica `root-app.yaml`
- **THEN** Argo CD crea las cinco Applications de `argocd/apps`

#### Scenario: Una carpeta sin recursión
- **WHEN** se revisa `root-app.yaml`
- **THEN** su origen es `argocd/apps` y la propia raíz no está dentro de esa carpeta

### Requirement: Una Application por componente

`argocd/apps` SHALL tener una Application por componente (`frontend`, `products-service`, `orders-service`, `products-db`, `orders-db`), cada una con origen `apps/<nombre>`, destino el clúster local (`https://kubernetes.default.svc`) y namespace `store`, y política `automated` con `prune: true` y `selfHeal: true`, y la opción `CreateNamespace=true`. Cada una SHALL llevar el finalizador `resources-finalizer.argocd.argoproj.io` para que, al borrarla, se eliminen sus recursos.

#### Scenario: Política de sincronización
- **WHEN** se revisa cada Application de componente
- **THEN** tiene `syncPolicy.automated.prune: true` y `syncPolicy.automated.selfHeal: true`

#### Scenario: Destino
- **WHEN** se revisa cada Application de componente
- **THEN** su destino es el namespace `store` y su origen es `apps/<nombre>` en la rama `main`

#### Scenario: Borrado en cascada
- **WHEN** se borra una Application de componente
- **THEN** sus recursos de Kubernetes se eliminan (finalizador), salvo los PVC de las bases, que conserva el StatefulSet

### Requirement: Autocorrección

Con `selfHeal` activo, un cambio hecho a mano en el clúster sobre un recurso gestionado SHALL revertirse al estado de git, y un cambio de tag de imagen en git SHALL desplegarse sin intervención.

#### Scenario: Cambio manual revertido
- **WHEN** alguien cambia a mano las réplicas de un Deployment gestionado
- **THEN** Argo CD las devuelve al valor de git

#### Scenario: Nueva imagen
- **WHEN** CI hace commit con un `newTag` nuevo
- **THEN** Argo CD pasa de `OutOfSync` a `Synced` y se hace un rolling update
