# Clúster EKS con un grupo de nodos administrado en subredes privadas
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.30.2"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Endpoint público limitado a los CIDR indicados (recomendado: tu IP)
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Quien crea el clúster recibe permisos de administrador para usar kubectl
  enable_cluster_creator_admin_permissions = true

  # Proveedor OIDC del clúster (lo necesita el rol del driver EBS CSI)
  enable_irsa = true

  # Addons base. El driver EBS CSI va aparte (ebs-csi.tf) para evitar una dependencia circular
  addons = {
    # Una sola réplica de CoreDNS: nodos t3.small de solo 11 pods (ver scripts/check-capacity.py)
    coredns = {
      configuration_values = jsonencode({
        replicaCount = 1
      })
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size
    }
  }
}
