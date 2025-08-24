variable "cluster_name" {
  description = "EKS Cluster name"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "private_subnets" {
  description = "Private subnets from VPC module"
  type        = list(string)
}

#variable "private_subnet_azs" {
#  type        = list(string)
#  description = "Availability zones of private subnets"
#}

variable "eks_version" {
  description = "Kubernetes version"
  type        = string
}

variable "node_group" {
  description = "Node group configuration (for Cluster Autoscaler)"
  type = object({
    enable         = bool
    instance_types = list(string)
    desired_size   = number
    min_size       = number
    max_size       = number
  })
  default = {
    enable         = true
    instance_types = ["t3.medium"]
    desired_size   = 2
    min_size       = 1
    max_size       = 4
  }
}

variable "scaling_type" {
  description = "Choose autoscaler: 'autoscaler' or 'karpenter'"
  type        = string
  default     = "autoscaler"
}

variable "autoscaler_chart_version" {
  description = "Version of the Cluster Autoscaler Helm chart"
  type        = string
  default     = "9.50.1"
}

variable "karpenter_chart_version" {
  description = "Version of the Karpenter Helm chart"
  type        = string
  default     = "0.37.2"
}

variable "eks_node_ami_id" {
  description = "Optional custom EKS node AMI ID. If empty, default EKS optimized AMI will be used."
  type        = string
  default     = ""
}

variable "jumpbox_ami_id" {
  description = "AMI ID for the jumpbox instance"
  type        = string
  default     = ""
}