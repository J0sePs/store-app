# Tasks

## 1. feature_list.json

- [x] 1.1 Crear `feature_list.json` en la raíz con 8 entradas (`change-0` a `change-7`) usando los nombres del orden aprobado; verificar con `python3 -c "import json; d=json.load(open('feature_list.json')); print(len(d['features']))"` que imprime `8`
- [x] 1.2 Marcar `bootstrap-harness` como `in_progress` durante la implementación y el resto como `pending`; verificar que solo una entrada está `in_progress` y que todos los campos (`id`, `name`, `description`, `status`, `evidence`) existen
- [x] 1.3 Verificar que los nombres de archivo y de entradas están en inglés y las descripciones en español (revisión manual contra `openspec/config.yaml`)

## 2. progress.md

- [x] 2.1 Crear `progress.md` en la raíz, en español, con estado actual, plantilla de sección por change (qué se hizo, evidencia, siguiente paso) y bloque "Siguiente paso"; verificar leyéndolo que no depende del chat
- [x] 2.2 Registrar la primera entrada (`bootstrap-harness`) con evidencia real una vez verificado el resto; verificar que apunta al siguiente change `products-service-fastapi`

## 3. init.sh

- [x] 3.1 Crear `init.sh` ejecutable (`chmod +x`) que verifique git, docker, node, python3, go, terraform, aws, kubectl y openspec, mostrando versión; verificar con `./init.sh` que imprime una línea por herramienta
- [x] 3.2 Hacer que acumule faltantes y los resuma al final sin abortar; verificar simulando una falta con `PATH` restringido y comprobando el aviso
- [x] 3.3 Correr tests de componentes existentes (`pytest`, `go test ./...`, `npm test -- --watch=false`) y omitir con aviso los inexistentes; verificar que hoy imprime "omitido" para los tres y termina con código 0
- [x] 3.4 Validar `feature_list.json` y avisar si hay más de un `in_progress`; verificar con una copia temporal modificada (en el directorio scratchpad) que el aviso aparece
- [x] 3.5 Comprobar que `init.sh` no contiene `terraform apply`, `terraform destroy`, `git push`, `kubectl apply` ni `aws` de escritura (`grep`); verificar `bash -n init.sh` sin errores

## 4. AGENTS.md

- [x] 4.1 Agregar en `AGENTS.md` la regla "al iniciar sesión, lee `progress.md` y `feature_list.json`; al cerrar un change, actualízalos" en la sección 4 (flujo de trabajo); verificar con `grep -n "progress.md" AGENTS.md`
- [x] 4.2 Actualizar la sección 2 (estructura) de `AGENTS.md` para listar `feature_list.json`, `progress.md` e `init.sh`; verificar con `grep`

## 5. Documentación y cierre

- [x] 5.1 Documentar en `README.md` de la raíz (crear si no existe, en español) cómo usar `init.sh`, `progress.md` y `feature_list.json`; verificar que el comando documentado corre tal cual
- [x] 5.2 Ejecutar `openspec validate bootstrap-harness` y `./init.sh`; verificar que ambos terminan sin errores
- [x] 5.3 Cerrar el change: `feature_list.json` con `bootstrap-harness` en `done` y `evidence` con los comandos ejecutados, y siguiente entrada de `progress.md`; verificar que `products-service-fastapi` queda `pending`

## Workflow follow-up

- Archivar el change con `/openspec-archive-change` tras la revisión del humano.
- No hacer `git push` ni commits sin confirmación.
