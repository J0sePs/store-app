provider "aws" {
  region = var.region

  # Etiqueta que se aplica a todos los recursos del proyecto
  default_tags {
    tags = {
      Project = "store"
    }
  }
}

# Datos del clúster que creó la etapa principal (debe existir antes de aplicar esta etapa)
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Los proveedores se autentican con "aws eks get-token": el token se pide en cada operación,
# no caduca a mitad del apply y no queda guardado en el estado.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}
