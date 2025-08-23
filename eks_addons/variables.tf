variable "cluster_name" {
  type = string
}

variable "scaling_type" {
  type = string
}

variable "karpenter_chart_version" {
  type = string
}

variable "autoscaler_chart_version" {
  type = string
}

variable "karpenter_oidc_arn" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "aws_region" {
  description = "AWS region where the cluster is running"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca" {
  description = "EKS cluster CA certificate"
  type        = string
}


