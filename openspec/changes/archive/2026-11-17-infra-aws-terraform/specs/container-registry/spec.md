## ADDED Requirements

### Requirement: Tres repositorios ECR

La infraestructura SHALL crear tres repositorios ECR privados con los nombres `frontend`, `products-service` y `orders-service`, a partir de una lista configurable (`ecr_repository_names`). Cada repositorio SHALL tener activado el escaneo de vulnerabilidades al subir una imagen y SHALL poder borrarse con `destroy` aunque contenga imágenes.

#### Scenario: Repositorios creados
- **WHEN** se aplican las variables por defecto
- **THEN** existen los repositorios `frontend`, `products-service` y `orders-service`

#### Scenario: Escaneo al subir
- **WHEN** se revisa la configuración de cada repositorio
- **THEN** el escaneo al subir está activado

#### Scenario: Destroy con imágenes
- **WHEN** se ejecuta `terraform destroy` y un repositorio contiene imágenes
- **THEN** el repositorio se elimina igualmente

### Requirement: Política de ciclo de vida

Cada repositorio SHALL tener una política de ciclo de vida que conserve solo las últimas N imágenes, con N configurable (`ecr_keep_last_images`, por defecto 10) y expire el resto.

#### Scenario: Valor por defecto
- **WHEN** se revisa la política de ciclo de vida
- **THEN** la regla expira las imágenes que superan la cantidad 10 (`imageCountMoreThan`)

#### Scenario: Valor personalizado
- **WHEN** `ecr_keep_last_images = 5`
- **THEN** la regla usa `imageCountMoreThan` igual a 5

### Requirement: Etiquetas de imagen

Los repositorios SHALL aceptar etiquetas mutables, porque CI puede repetir la subida de un mismo SHA tras un fallo. El uso de la etiqueta `latest` queda prohibido por la regla del proyecto y se hace cumplir en CI, no en ECR.

#### Scenario: Repetir una subida
- **WHEN** CI vuelve a subir una imagen con el mismo SHA
- **THEN** ECR no rechaza la subida
