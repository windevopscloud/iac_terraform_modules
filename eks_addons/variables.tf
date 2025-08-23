variable "cluster_name" { 
    type = string 
}

variable "cluster_endpoint" { 
    type = string 
}

variable "cluster_ca" { 
    type = string 
}

variable "private_subnets" {
     type = list(string) 
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