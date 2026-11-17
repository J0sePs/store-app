## ADDED Requirements

### Requirement: Lista de features por change

El repositorio SHALL contener `feature_list.json` en la raíz con un objeto `features`, que incluye una entrada por cada change del orden aprobado, en ese orden: `bootstrap-harness`, `products-service-fastapi`, `orders-service-go`, `frontend-angular`, `infra-aws-terraform`, `gitops-manifests`, `ci-github-actions`, `demo-visible-change`. Cada entrada SHALL tener los campos `id`, `name`, `description`, `status` y `evidence`. `status` SHALL ser uno de `pending`, `in_progress` o `done`.

#### Scenario: Estructura válida
- **WHEN** se parsea `feature_list.json`
- **THEN** es JSON válido y contiene 8 entradas con los campos `id`, `name`, `description`, `status`, `evidence`
- **AND** el `name` de cada entrada coincide con el nombre del change aprobado

#### Scenario: Estado inicial
- **WHEN** se termina `bootstrap-harness`
- **THEN** su entrada tiene `status: "done"` y `evidence` no vacío
- **AND** las demás entradas tienen `status: "pending"` y `evidence` vacío

#### Scenario: Un solo change activo
- **WHEN** se inspecciona `feature_list.json` en cualquier momento
- **THEN** a lo sumo una entrada tiene `status: "in_progress"`

#### Scenario: Done exige evidencia
- **WHEN** una entrada tiene `status: "done"`
- **THEN** su campo `evidence` no está vacío

### Requirement: Bitácora de progreso

El repositorio SHALL contener `progress.md` en la raíz, escrito en español. Al cerrar cada change se SHALL agregar una sección que incluya: qué se hizo, la evidencia (tests y comandos ejecutados) y el siguiente paso. `progress.md` SHALL poder leerse por cualquier agente al iniciar sesión sin depender del historial del chat.

#### Scenario: Entrada al cerrar un change
- **WHEN** un change se cierra
- **THEN** `progress.md` tiene una sección nueva con fecha, nombre del change, qué se hizo, evidencia y siguiente paso

#### Scenario: Siguiente paso visible
- **WHEN** un agente abre `progress.md` al iniciar sesión
- **THEN** encuentra el siguiente paso en la última sección, sin recorrer el archivo completo

### Requirement: Verificación del entorno con init.sh

`init.sh` SHALL ser ejecutable desde la raíz del repo. SHALL verificar la presencia de `git`, `docker`, `node`, `python3`, `go`, `terraform`, `aws`, `kubectl` y `openspec`, mostrar la versión de cada herramienta encontrada y avisar de forma explícita cuáles faltan. SHALL correr los tests de los componentes que ya existan (`products-service`, `orders-service`, `frontend`) y omitir, con un aviso, los que no existan. No SHALL ejecutar `terraform apply`, `terraform destroy`, `git push`, `kubectl apply` ni llamadas a `aws` que modifiquen recursos.

#### Scenario: Todas las herramientas presentes
- **WHEN** se ejecuta `./init.sh` y las 9 herramientas están instaladas
- **THEN** imprime la versión de cada una y no reporta faltantes

#### Scenario: Herramienta faltante
- **WHEN** se ejecuta `./init.sh` y una herramienta no está instalada
- **THEN** imprime un aviso con el nombre de la herramienta faltante y un resumen final con los faltantes
- **AND** no se interrumpe antes de revisar las demás

#### Scenario: Componentes aún inexistentes
- **WHEN** se ejecuta `./init.sh` y `products-service/` no existe
- **THEN** avisa que se omiten sus tests y termina sin tratarlo como fallo

#### Scenario: Componente existente con tests
- **WHEN** existe un componente con tests y `./init.sh` corre
- **THEN** ejecuta el comando de tests de `AGENTS.md` para ese componente
- **AND** el código de salida de `init.sh` es distinto de 0 si esos tests fallan

### Requirement: Regla de sesión en AGENTS.md

`AGENTS.md` SHALL incluir la regla: "al iniciar sesión, lee `progress.md` y `feature_list.json`; al cerrar un change, actualízalos".

#### Scenario: Regla presente
- **WHEN** se busca "progress.md" y "feature_list.json" en `AGENTS.md`
- **THEN** aparece la regla de inicio de sesión y de cierre de change

#### Scenario: Compatibilidad entre agentes
- **WHEN** Claude Code u opencode inician sesión en el repo
- **THEN** ambos reciben la regla, porque `CLAUDE.md` importa `AGENTS.md`
