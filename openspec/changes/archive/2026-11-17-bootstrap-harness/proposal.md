## Why

Los changes del proyecto se ejecutarán en varias sesiones y con distintos agentes (Claude Code, opencode). Sin estado persistente, cada sesión pierde contexto, repite trabajo o marca cosas como "hechas" sin evidencia. Hace falta un harness mínimo antes de escribir código de cualquier servicio.

## What Changes

- Crear `feature_list.json` en la raíz: una entrada por change del orden aprobado (0 a 7), con `id`, `name`, `description`, `status` (`pending` / `in_progress` / `done`) y `evidence`.
- Crear `progress.md` en la raíz: bitácora en español. Al cerrar cada change se agrega qué se hizo, la evidencia (tests, comandos) y el siguiente paso.
- Crear `init.sh` en la raíz: verifica herramientas (git, docker, node, python3, go, terraform, aws, kubectl, openspec), muestra versiones, avisa lo que falte y corre los tests de los componentes que ya existan.
- Agregar en `AGENTS.md` la regla: "al iniciar sesión, lee `progress.md` y `feature_list.json`; al cerrar un change, actualízalos".
- Se parte de las plantillas de la skill `harness-creator`, adaptadas al proyecto (estados y textos en español).

No hay cambios **BREAKING**.

## Capabilities

### New Capabilities

- `project-harness`: estado persistente de sesión (`feature_list.json`, `progress.md`), verificación del entorno (`init.sh`) y la regla de arranque/cierre de sesión para agentes.

### Modified Capabilities

Ninguna (no existen specs previos en `openspec/specs/`).

## Impact

- **Componente afectado:** ninguno de la arquitectura en ejecución (frontend, servicios, infra). Solo tooling del repo `store-app`.
- **Archivos nuevos:** `feature_list.json`, `progress.md`, `init.sh`.
- **Archivo modificado:** `AGENTS.md` (una regla nueva).
- **Dependencias:** `bash`; `node` o `python3` para validar el JSON (opcional, `init.sh` degrada con aviso si falta).
- **Fuera de alcance:** no se toca `../store-gitops`, ni se escribe código de servicios. Ejecutar `git push` o `terraform apply` sigue requiriendo confirmación.
