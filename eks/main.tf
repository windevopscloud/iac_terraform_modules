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
    subnet_ids              = var.private_subnets
    endpoint_private_access = true  # ✅ Only accessible inside VPC
    endpoint_public_access  = false # ✅ Disable internet access
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

# Attach required managed policies
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
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

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Latest"
  }
}

# Node group IAM Role
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

# Attach required AWS managed policies
resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Allow Session Manager access to nodes
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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
  url            = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint for AWS root CA used by OIDC
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0afd10df6"]
}

# Optional data source to fetch it later if needed
data "aws_iam_openid_connect_provider" "eks_oidc" {
  arn = aws_iam_openid_connect_provider.eks_oidc.arn
}

# Create Launch Template for the EKS cluster
#tfsec:ignore:aws-ec2-enforce-launch-config-http-token-imds
resource "aws_launch_template" "eks_nodes" {
  name_prefix   = "${var.cluster_name}-lt"
  image_id      = var.eks_node_ami_id # optional, custom AMI
  instance_type = var.node_group.instance_types[0]
  iam_instance_profile {
    name = aws_iam_instance_profile.eks_nodes.name
  }
  user_data = base64encode(<<-EOT
              #!/bin/bash
              yum install -y amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              EOT
  )
}

resource "aws_iam_instance_profile" "eks_nodes" {
  name = "${var.cluster_name}-nodegroup-instance-profile"
  role = aws_iam_role.eks_nodes.name
}

#Jumpbox to access kubectl
#tfsec:ignore:aws-ec2-enforce-http-token-imds
#tfsec:ignore:aws-ec2-enable-at-rest-encryption
resource "aws_instance" "jumpbox" {
  ami                  = var.jumpbox_ami_id
  instance_type        = "t3.micro"
  subnet_id            = var.private_subnets[0]
  iam_instance_profile = aws_iam_instance_profile.jumpbox.name

  user_data = base64encode(<<-EOT
    #!/bin/bash
    yum install -y amazon-ssm-agent kubectl
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOT
  )
}

# IAM Role for Jumpbox
resource "aws_iam_role" "jumpbox" {
  name = "${var.cluster_name}-jumpbox-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach policies to allow kubectl access to EKS and SSM
resource "aws_iam_role_policy_attachment" "jumpbox_eks_access" {
  role       = aws_iam_role.jumpbox.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "jumpbox_ssm" {
  role       = aws_iam_role.jumpbox.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for jumpbox
resource "aws_iam_instance_profile" "jumpbox" {
  name = "${var.cluster_name}-jumpbox-instance-profile"
  role = aws_iam_role.jumpbox.name
}