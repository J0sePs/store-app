# Quita la marca de StorageClass por defecto a gp2 (la que trae EKS) para que solo haya una
resource "kubernetes_annotations" "gp2_not_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  # gp2 ya trae esa anotación puesta por EKS
  force = true
}

# StorageClass gp3 por defecto, respaldada por el driver EBS CSI (addon creado en la etapa principal).
# Está en esta etapa porque necesita un clúster ya existente.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }

  depends_on = [kubernetes_annotations.gp2_not_default]
}
