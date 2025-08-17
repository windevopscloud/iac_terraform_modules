variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "create_public_subnets" {
  description = "Create public subnets? yes/no"
  type        = string
  default     = "no"
}

variable "public_subnets" {
  description = "List of CIDRs for public subnets"
  type        = list(string)
  default     = []
}

variable "create_private_subnets" {
  description = "Create private subnets? yes/no"
  type        = string
  default     = "no"
}

variable "private_subnets" {
  description = "List of CIDRs for private subnets"
  type        = list(string)
  default     = []
}

variable "create_isolated_subnets" {
  description = "Create isolated subnets? yes/no"
  type        = string
  default     = "no"
}

variable "isolated_subnets" {
  description = "List of CIDRs for isolated subnets"
  type        = list(string)
  default     = []
}

variable "create_igw" {
  description = "Create Internet Gateway? yes/no"
  type        = string
  default     = "no"
}

variable "create_nat_gateway" {
  description = "Create NAT Gateway? yes/no"
  type        = string
  default     = "no"
}

# NACL Rules - Public
variable "public_nacl_ingress" {
  description = "Ingress rules for public NACL"
  type = list(object({
    rule_number = number
    protocol    = string
    action      = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  }))
  default = [
    { rule_number = 100, protocol = "6", action = "allow", cidr_block = "0.0.0.0/0", from_port = 80,  to_port = 80 },
    { rule_number = 110, protocol = "6", action = "allow", cidr_block = "0.0.0.0/0", from_port = 443, to_port = 443 },
    { rule_number = 120, protocol = "6", action = "allow", cidr_block = "0.0.0.0/0", from_port = 22,  to_port = 22 }
  ]
}

variable "public_nacl_egress" {
  description = "Egress rules for public NACL"
  type = list(object({
    rule_number = number
    protocol    = string
    action      = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  }))
  default = [
    { rule_number = 100, protocol = "-1", action = "allow", cidr_block = "0.0.0.0/0", from_port = 0, to_port = 0 }
  ]
}

# NACL Rules - Private (default allow all)
variable "private_nacl_ingress" {
  description = "Ingress rules for private NACL"
  type = list(object({
    rule_number = number
    protocol    = string
    action      = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  }))
  default = [
    { rule_number = 100, protocol = "-1", action = "allow", cidr_block = "0.0.0.0/0", from_port = 0, to_port = 0 }
  ]
}

variable "private_nacl_egress" {
  description = "Egress rules for private NACL"
  type = list(object({
    rule_number = number
    protocol    = string
    action      = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  }))
  default = [
    { rule_number = 100, protocol = "-1", action = "allow", cidr_block = "0.0.0.0/0", from_port = 0, to_port = 0 }
  ]
}

# NACL Rules - Isolated (default only allow VPC CIDR)
variable "isolated_nacl_ingress" {
  description = "Ingress rules for isolated NACL"
  type = list(object({
    rule_number = number
    protocol    = string
    action      = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  }))
  default = [
    { rule_number = 100, protocol = "-1", action = "allow", cidr_block = "10.0.0.0/16", from_port = 0, to_port = 0 }
  ]
}

variable "isolated_nacl_egress" {
  description = "Egress rules for isolated NACL"
  type = list(object({
    rule_number = number
    protocol    = string
    action      = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  }))
  default = [
    { rule_number = 100, protocol = "-1", action = "allow", cidr_block = "10.0.0.0/16", from_port = 0, to_port = 0 }
  ]
}