# Rol IAM del driver EBS CSI (IRSA): solo lo puede asumir su cuenta de servicio en kube-system
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.11.1"

  name = "${var.cluster_name}-ebs-csi"

  # Política administrada AmazonEBSCSIDriverPolicy
  attach_ebs_csi_policy = true

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

# Addon del driver. Va fuera del módulo EKS porque el rol necesita el OIDC que crea ese módulo
# (dentro del módulo habría una dependencia circular) y porque sus pods necesitan nodos ya creados.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_irsa.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.eks]
}
