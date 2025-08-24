# -----------------------------
# EKS Cluster
# -----------------------------
#tfsec:ignore:aws-eks-no-public-cluster-access
#tfsec:ignore:aws-eks-no-public-cluster-access-to-cidr
#tfsec:ignore:aws-eks-encrypt-secrets
#tfsec:ignore:aws-eks-enable-control-plane-logging
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
# Data required for outputs
# -----------------------------
data "aws_eks_cluster" "this" {
  name = aws_eks_cluster.this.name
}

data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}

# Create IAM OIDC provider for the EKS cluster
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]

  # Thumbprint for AWS root CA used by OIDC
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0afd10df6"]
}

# Optional data source to fetch it later if needed
data "aws_iam_openid_connect_provider" "eks_oidc" {
  arn = aws_iam_openid_connect_provider.eks_oidc.arn
}
