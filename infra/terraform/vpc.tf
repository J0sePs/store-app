# Zonas de disponibilidad disponibles en la región
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# VPC con subredes públicas (balanceadores) y privadas (nodos) y un solo NAT gateway
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.8.0"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  # Un solo NAT para ahorrar costo (se pierde alta disponibilidad)
  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Etiquetas para que Kubernetes cree los balanceadores en las subredes correctas
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
