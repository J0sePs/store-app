## ADDED Requirements

### Requirement: PostgreSQL ajustado a poca memoria

Cada StatefulSet de PostgreSQL SHALL pedir 128 MiB de memoria (`requests`) y limitarla a 256 MiB, y SHALL arrancar `postgres` con `shared_buffers=32MB` y `max_connections=20` para que su consumo real quepa en ese presupuesto. El servicio asociado usa muy pocas conexiones, por lo que ese máximo es suficiente.

#### Scenario: Recursos
- **WHEN** se revisa el StatefulSet de cada base
- **THEN** `requests.memory` es `128Mi` y `limits.memory` es `256Mi`

#### Scenario: Parámetros de arranque
- **WHEN** se revisa el comando de arranque del contenedor
- **THEN** ejecuta `postgres` con `-c shared_buffers=32MB` y `-c max_connections=20`

#### Scenario: Consumo real
- **WHEN** PostgreSQL arranca con esos parámetros y el límite de 256 MiB y atiende consultas del servicio
- **THEN** su memoria en uso queda por debajo del límite y no es terminado por falta de memoria
