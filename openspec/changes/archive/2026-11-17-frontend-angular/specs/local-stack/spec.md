## ADDED Requirements

### Requirement: Sistema completo con docker compose

El repositorio SHALL incluir `docker-compose.yml` en la raíz que levante cinco servicios: `frontend`, `products-service`, `products-db`, `orders-service` y `orders-db`, sin necesitar AWS. Cada servicio de negocio SHALL usar solo su propia base de datos. Las bases de datos SHALL usar un volumen para conservar los datos. Los servicios SHALL esperar a que su base de datos esté lista. Solo el frontend SHALL publicarse al host, en el puerto 80 por defecto (configurable con `FRONTEND_PORT`).

#### Scenario: Arranque completo
- **WHEN** se ejecuta `docker compose up --build` con el `.env` creado
- **THEN** los cinco servicios quedan en ejecución y `GET http://localhost/api/products/health` y `GET http://localhost/api/orders/health` responden 200

#### Scenario: Aislamiento de bases de datos
- **WHEN** se inspecciona la configuración de `products-service` y `orders-service`
- **THEN** cada uno apunta únicamente a su base (`products-db` y `orders-db` respectivamente)

#### Scenario: Persistencia
- **WHEN** se crea un pedido y se ejecuta `docker compose restart`
- **THEN** el pedido sigue existiendo

#### Scenario: Solo el frontend es accesible
- **WHEN** se listan los puertos publicados
- **THEN** solo el frontend publica un puerto al host

### Requirement: Credenciales fuera de git

Las contraseñas de las bases de datos SHALL provenir de variables de entorno definidas en un archivo `.env` local ignorado por git. El repositorio SHALL incluir `.env.example` con nombres de variables y valores de ejemplo no secretos. Si falta una variable obligatoria, `docker compose` SHALL fallar con un mensaje en español que indique copiar `.env.example` a `.env`.

#### Scenario: Falta el .env
- **WHEN** se ejecuta `docker compose config` sin `.env`
- **THEN** falla con un mensaje en español que indica copiar `.env.example` a `.env`

#### Scenario: .env no versionado
- **WHEN** se ejecuta `git check-ignore .env`
- **THEN** el archivo está ignorado y `.env.example` no lo está

### Requirement: Versiones visibles en local

`docker-compose.yml` SHALL permitir indicar `APP_VERSION` para cada servicio y para la construcción del frontend, con valor `dev` por defecto.

#### Scenario: Versiones por defecto
- **WHEN** se levanta el sistema sin indicar versiones
- **THEN** el pie de página muestra `dev` para el frontend y para ambos servicios

#### Scenario: Versión personalizada
- **WHEN** se levanta con `PRODUCTS_APP_VERSION=2.0.0`
- **THEN** `GET /api/products/health` devuelve `"version": "2.0.0"`
