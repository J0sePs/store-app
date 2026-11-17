# Proveedor de AWS. Las credenciales salen del entorno o del perfil del usuario (nunca del código).
provider "aws" {
  region = var.region

  # Etiqueta que se aplica a todos los recursos del proyecto
  default_tags {
    tags = {
      Project = "store"
    }
  }
}
