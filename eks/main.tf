# -----------------------------
# EKS Cluster
# -----------------------------
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.eks_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = var.private_subnets
  }
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# -----------------------------
# Managed Node Group (Cluster Autoscaler)
# -----------------------------
resource "aws_eks_node_group" "this" {
  count           = var.node_group.enable && var.scaling_type == "autoscaler" ? 1 : 0
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnets

  scaling_config {
    desired_size = var.node_group.desired_size
    min_size     = var.node_group.min_size
    max_size     = var.node_group.max_size
  }

  instance_types = var.node_group.instance_types
}

resource "aws_iam_role" "eks_nodes" {
  name               = "${var.cluster_name}-eks-nodegroup-role"
  assume_role_policy = data.aws_iam_policy_document.eks_nodes_assume_role.json
}

data "aws_iam_policy_document" "eks_nodes_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# -----------------------------
# Cluster Autoscaler via Helm
# -----------------------------
resource "helm_release" "autoscaler" {
  count      = var.scaling_type == "autoscaler" ? 1 : 0
  name       = "autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "autoscaler"
  namespace  = "kube-system"
  version    = var.autoscaler_chart_version

  values = [
    yamlencode({
      autoDiscovery = { clusterName = aws_eks_cluster.this.name }
      awsRegion     = var.aws_region
      rbac = { serviceAccount = { create = true, name = "autoscaler" } }
      extraArgs = [
        "--balance-similar-node-groups",
        "--skip-nodes-with-local-storage=false",
        "--skip-nodes-with-system-pods=false"
      ]
    })
  ]
}

# -----------------------------
# Dynamic OIDC provider for Karpenter
# -----------------------------
data "aws_eks_cluster" "this" {
  name = aws_eks_cluster.this.name
}

data "aws_iam_openid_connect_provider" "eks_oidc" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
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
      Effect = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.eks_oidc.arn }
      Action = "sts:AssumeRoleWithWebIdentity"
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
      clusterName = aws_eks_cluster.this.name
      aws         = { clusterEndpoint = aws_eks_cluster.this.endpoint }
    })
  ]
}

# -----------------------------
# Tag private subnets for Karpenter
# -----------------------------
resource "aws_subnet" "tag_private_for_karpenter" {
  count = var.scaling_type == "karpenter" ? length(var.private_subnets) : 0
  id    = var.private_subnets[count.index]

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# -----------------------------
# Karpenter EC2NodeClass
# -----------------------------
resource "kubernetes_manifest" "karpenter_ec2nodeclass" {
  count    = var.scaling_type == "karpenter" ? 1 : 0
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
  count    = var.scaling_type == "karpenter" ? 1 : 0
  manifest = {
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata   = { name = "default" }
    spec = {
      requirements = [
        { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
        { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot","on-demand"] }
      ]
      limits = { resources = { cpu = "1000" } }
      ttlSecondsAfterEmpty = 30
      providerRef = { name = "default-ec2nodeclass" }
    }
  }
}