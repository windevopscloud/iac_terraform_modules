# -----------------------------
# Cluster Autoscaler via Helm
# -----------------------------
resource "helm_release" "autoscaler" {
  count      = var.scaling_type == "autoscaler" ? 1 : 0
  name       = "autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.autoscaler_chart_version

  values = [
    yamlencode({
      autoDiscovery = { clusterName = var.cluster_name }
      awsRegion     = var.aws_region
      rbac          = { serviceAccount = { create = true, name = "autoscaler" } }
      extraArgs = [
        "--balance-similar-node-groups",
        "--skip-nodes-with-local-storage=false",
        "--skip-nodes-with-system-pods=false"
      ]
    })
  ]
}

# -----------------------------
# Karpenter IAM Role
# -----------------------------
resource "aws_iam_role" "karpenter" {
  count = var.scaling_type == "karpenter" ? 1 : 0
  name  = "${var.cluster_name}-karpenter-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.karpenter_oidc_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
    }]
  })
}

# -----------------------------
# Karpenter Helm Deployment
# -----------------------------
resource "helm_release" "karpenter" {
  count      = var.scaling_type == "karpenter" ? 1 : 0
  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  namespace  = "karpenter"
  version    = var.karpenter_chart_version

  values = [
    yamlencode({
      serviceAccount = {
        create      = true
        name        = "karpenter"
        annotations = { "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter[0].arn }
      }
      clusterName = var.cluster_name
      aws         = { clusterEndpoint = var.cluster_endpoint }
    })
  ]
}

# -----------------------------
# Tag private subnets for Karpenter
# -----------------------------
resource "aws_ec2_tag" "tag_private_for_karpenter" {
  for_each    = { for idx, subnet_id in var.private_subnets : idx => subnet_id }
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "owned"
}

# -----------------------------
# Karpenter EC2NodeClass
# -----------------------------
resource "kubernetes_manifest" "karpenter_ec2nodeclass" {
  count = var.scaling_type == "karpenter" ? 1 : 0
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata   = { name = "default-ec2nodeclass" }
    spec = {
      subnetSelector = {
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      }
      securityGroupSelector = {
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      }
    }
  }
}

# -----------------------------
# Karpenter Provisioner
# -----------------------------
resource "kubernetes_manifest" "karpenter_provisioner" {
  count = var.scaling_type == "karpenter" ? 1 : 0
  manifest = {
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata   = { name = "default" }
    spec = {
      requirements = [
        { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
        { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot", "on-demand"] }
      ]
      limits               = { resources = { cpu = "1000" } }
      ttlSecondsAfterEmpty = 30
      providerRef          = { name = "default-ec2nodeclass" }
    }
  }
}
