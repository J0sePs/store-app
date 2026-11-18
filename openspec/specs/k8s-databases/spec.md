# k8s-databases Specification

## Purpose
PostgreSQL de cada servicio como StatefulSet con PVC gp3 y Service headless, sin credenciales en git.

## Requirements

### Requirement: PostgreSQL como StatefulSet con almacenamiento gp3

`products-db` y `orders-db` SHALL desplegarse como `StatefulSet` de una réplica con la imagen `postgres:16-alpine`, cada uno con su propio PVC creado por `volumeClaimTemplates` con `storageClassName: gp3`, `ReadWriteOnce` y 5 GiB, y los datos en un subdirectorio del volumen (`PGDATA`). Cada StatefulSet SHALL tener `requests` y `limits`, probes de readiness y liveness con `pg_isready`, y ejecutarse con un usuario que no sea root.

#### Scenario: PVC gp3
- **WHEN** se revisa el `volumeClaimTemplates` de cada StatefulSet
- **THEN** usa `storageClassName: gp3` y solicita 5Gi

#### Scenario: Una base por servicio
- **WHEN** se revisan los dos StatefulSet
- **THEN** son recursos distintos (`products-db` y `orders-db`) con volúmenes distintos y ningún servicio apunta a la base del otro

#### Scenario: Datos en subdirectorio
- **WHEN** se revisan las variables del contenedor
- **THEN** `PGDATA` apunta a un subdirectorio de la ruta del volumen

### Requirement: Service headless

Cada base SHALL tener un Service headless (`clusterIP: None`) con el mismo nombre que su StatefulSet (`products-db`, `orders-db`), puerto 5432, que es su `serviceName`.

#### Scenario: Headless
- **WHEN** se revisan los Services de las bases
- **THEN** tienen `clusterIP: None`, puerto 5432 y coinciden con el `serviceName` del StatefulSet

#### Scenario: Resolución por nombre
- **WHEN** un servicio se conecta a `products-db:5432` dentro del clúster
- **THEN** el nombre resuelve al pod de la base

### Requirement: Credenciales fuera de git

Los manifiestos NO SHALL contener contraseñas ni objetos `Secret`. Cada base SHALL leer `POSTGRES_PASSWORD` de un Secret creado a mano (`products-db-credentials`, `orders-db-credentials`), que también incluye la `DATABASE_URL` de su servicio. El usuario y el nombre de la base SHALL ser valores no secretos de los manifiestos. El repositorio SHALL ignorar archivos de secretos locales.

#### Scenario: Sin Secrets en git
- **WHEN** se buscan `kind: Secret` y la palabra `password` con valor en el repositorio
- **THEN** no hay ningún Secret ni contraseña escrita

#### Scenario: Secret ausente
- **WHEN** el Secret de una base no existe en el clúster
- **THEN** el pod no arranca (error de configuración) y arranca solo cuando el Secret se crea

#### Scenario: Archivos ignorados
- **WHEN** se ejecuta `git check-ignore` sobre `secret.yaml` y `.env`
- **THEN** ambos están ignorados

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
