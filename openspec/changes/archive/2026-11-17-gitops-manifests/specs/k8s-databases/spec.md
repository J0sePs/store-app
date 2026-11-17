## ADDED Requirements

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
