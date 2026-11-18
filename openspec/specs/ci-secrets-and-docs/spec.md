# ci-secrets-and-docs Specification

## Purpose
Secretos y variables de la CI documentados, permisos mínimos, datos no confiables fuera de los comandos de shell y revisión estática de los workflows.

## Requirements

### Requirement: Secretos y variables documentados

El `README.md` de la raíz SHALL tener una sección en español que liste: el secret `GITOPS_TOKEN` (token de GitHub con permiso de lectura y escritura de contenido solo sobre `store-gitops`, cómo crearlo y dónde guardarlo), la variable `AWS_ROLE_ARN` (salida `github_actions_role_arn` de Terraform) y la variable opcional `AWS_REGION` (por defecto `us-east-1`); cómo funciona el flujo; qué hacer si el push a `store-gitops` falla por protección de rama; y que los workflows corren en GitHub, no en local.

#### Scenario: Lista de secretos
- **WHEN** se lee la sección de CI del README
- **THEN** aparecen `GITOPS_TOKEN`, `AWS_ROLE_ARN` y `AWS_REGION`, con su tipo (secret o variable) y de dónde sale cada valor

#### Scenario: Sin valores reales
- **WHEN** se busca en el README y en los workflows
- **THEN** no hay tokens, llaves ni ARN reales

### Requirement: Permisos mínimos y datos no confiables

Los workflows SHALL declarar `permissions` explícitos a nivel de workflow (`contents: read`). Los valores que no son constantes (SHA, nombres, registro) SHALL pasarse a los scripts como variables de entorno y no interpolarse directamente en comandos de shell con `${{ }}`. Las acciones de terceros SHALL fijarse por versión mayor.

#### Scenario: Permisos explícitos
- **WHEN** se revisa cada workflow
- **THEN** declara `permissions` y ningún job pide más de lo que necesita

#### Scenario: Sin inyección
- **WHEN** se buscan expresiones `${{ }}` dentro de bloques `run`
- **THEN** no hay ninguna con datos controlados por el usuario (ramas, títulos, mensajes de commit)

#### Scenario: Versiones fijadas
- **WHEN** se revisan las líneas `uses:`
- **THEN** todas llevan una versión mayor explícita (por ejemplo `@v7`)

### Requirement: Revisión estática de los workflows

Los workflows y el script de gitops SHALL poder revisarse sin ejecutarlos en GitHub: `actionlint` sin errores y el script probado en local contra un repositorio git temporal.

#### Scenario: actionlint
- **WHEN** se ejecuta `actionlint` sobre `.github/workflows/`
- **THEN** termina sin errores

#### Scenario: Prueba local del script
- **WHEN** se ejecuta el script contra una copia temporal de `store-gitops` con un remoto local
- **THEN** actualiza la imagen, verifica `APP_VERSION`, hace commit y push, y supera los casos de remoto adelantado, conflicto, sin cambios y versión incorrecta
