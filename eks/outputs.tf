output "cluster_id" {
  value = aws_eks_cluster.this.id
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "node_group_ids" {
  value = aws_eks_node_group.this[*].id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.this.name
}

output "eks_cluster_ca" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "karpenter_oidc_arn" {
  value = data.aws_iam_openid_connect_provider.eks_oidc.arn
}