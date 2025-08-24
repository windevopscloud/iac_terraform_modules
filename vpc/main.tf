# -----------------------------
# VPC
# -----------------------------
#tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "custom-vpc" }
}

# -----------------------------
# INTERNET GATEWAY
# -----------------------------
resource "aws_internet_gateway" "this" {
  count  = var.create_igw == "yes" ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = { Name = "custom-igw" }
}

# -----------------------------
# ELASTIC IPS FOR NAT GATEWAYS
# -----------------------------
resource "aws_eip" "nat" {
  count = var.create_nat_gateway == "yes" ? length(var.public_subnets) : 0
  vpc   = true
  tags  = { Name = "nat-eip-${count.index + 1}" }
}

# -----------------------------
# NAT GATEWAYS
# -----------------------------
resource "aws_nat_gateway" "this" {
  count         = var.create_nat_gateway == "yes" ? length(var.public_subnets) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # NAT in corresponding public subnet/AZ
  tags          = { Name = "nat-gateway-${count.index + 1}" }
}

# -----------------------------
# PUBLIC SUBNETS
# -----------------------------
resource "aws_subnet" "public" {
  count                   = var.create_public_subnets == "yes" ? length(var.public_subnets) : 0
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "public-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  count  = var.create_public_subnets == "yes" && var.create_igw == "yes" ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = { Name = "public-rt" }
}

resource "aws_route" "public_internet" {
  count                  = var.create_public_subnets == "yes" && var.create_igw == "yes" ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public_assoc" {
  count          = var.create_public_subnets == "yes" ? length(var.public_subnets) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# -----------------------------
# PRIVATE SUBNETS
# -----------------------------
resource "aws_subnet" "private" {
  count             = var.create_private_subnets == "yes" ? length(var.private_subnets) : 0
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "private-${count.index + 1}" }
}

# Private Route Table
resource "aws_route_table" "private" {
  count  = var.create_private_subnets == "yes" && var.create_nat_gateway == "yes" ? length(var.private_subnets) : 0
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "private-rt-${count.index + 1}"
  }
}

# Route for Private Subnets to NAT per AZ
resource "aws_route" "private_internet" {
  count                  = var.create_private_subnets == "yes" && var.create_nat_gateway == "yes" ? length(var.private_subnets) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private_assoc" {
  count          = var.create_private_subnets == "yes" && var.create_nat_gateway == "yes" ? length(var.private_subnets) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# -----------------------------
# ISOLATED SUBNETS
# -----------------------------
resource "aws_subnet" "isolated" {
  count             = var.create_isolated_subnets == "yes" ? length(var.isolated_subnets) : 0
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.isolated_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "isolated-${count.index + 1}" }
}

# -----------------------------
# PUBLIC NACL
# -----------------------------
resource "aws_network_acl" "public" {
  count  = var.create_public_subnets == "yes" ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = { Name = "public-nacl" }

  subnet_ids = var.create_public_subnets == "yes" ? aws_subnet.public[*].id : []
}

resource "aws_network_acl_rule" "public_ingress" {
  count          = var.create_public_subnets == "yes" ? length(var.public_nacl_ingress) : 0
  network_acl_id = aws_network_acl.public[0].id
  rule_number    = var.public_nacl_ingress[count.index].rule_number
  egress         = false
  protocol       = var.public_nacl_ingress[count.index].protocol
  rule_action    = var.public_nacl_ingress[count.index].action
  cidr_block     = var.public_nacl_ingress[count.index].cidr_block
  from_port      = var.public_nacl_ingress[count.index].from_port
  to_port        = var.public_nacl_ingress[count.index].to_port
}

resource "aws_network_acl_rule" "public_egress" {
  count          = var.create_public_subnets == "yes" ? length(var.public_nacl_egress) : 0
  network_acl_id = aws_network_acl.public[0].id
  rule_number    = var.public_nacl_egress[count.index].rule_number
  egress         = true
  protocol       = var.public_nacl_egress[count.index].protocol
  rule_action    = var.public_nacl_egress[count.index].action
  cidr_block     = var.public_nacl_egress[count.index].cidr_block
  from_port      = var.public_nacl_egress[count.index].from_port
  to_port        = var.public_nacl_egress[count.index].to_port
}

# -----------------------------
# PRIVATE NACL
# -----------------------------
resource "aws_network_acl" "private" {
  count  = var.create_private_subnets == "yes" ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = { Name = "private-nacl" }

  subnet_ids = var.create_private_subnets == "yes" ? aws_subnet.private[*].id : []
}

resource "aws_network_acl_rule" "private_ingress" {
  count          = var.create_private_subnets == "yes" ? length(var.private_nacl_ingress) : 0
  network_acl_id = aws_network_acl.private[0].id
  rule_number    = var.private_nacl_ingress[count.index].rule_number
  egress         = false
  protocol       = var.private_nacl_ingress[count.index].protocol
  rule_action    = var.private_nacl_ingress[count.index].action
  cidr_block     = var.private_nacl_ingress[count.index].cidr_block
  from_port      = var.private_nacl_ingress[count.index].from_port
  to_port        = var.private_nacl_ingress[count.index].to_port
}

resource "aws_network_acl_rule" "private_egress" {
  count          = var.create_private_subnets == "yes" ? length(var.private_nacl_egress) : 0
  network_acl_id = aws_network_acl.private[0].id
  rule_number    = var.private_nacl_egress[count.index].rule_number
  egress         = true
  protocol       = var.private_nacl_egress[count.index].protocol
  rule_action    = var.private_nacl_egress[count.index].action
  cidr_block     = var.private_nacl_egress[count.index].cidr_block
  from_port      = var.private_nacl_egress[count.index].from_port
  to_port        = var.private_nacl_egress[count.index].to_port
}

# -----------------------------
# ISOLATED NACL
# -----------------------------
resource "aws_network_acl" "isolated" {
  count  = var.create_isolated_subnets == "yes" ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = { Name = "isolated-nacl" }

  subnet_ids = var.create_isolated_subnets == "yes" ? aws_subnet.isolated[*].id : []
}

resource "aws_network_acl_rule" "isolated_ingress" {
  count          = var.create_isolated_subnets == "yes" ? length(var.isolated_nacl_ingress) : 0
  network_acl_id = aws_network_acl.isolated[0].id
  rule_number    = var.isolated_nacl_ingress[count.index].rule_number
  egress         = false
  protocol       = var.isolated_nacl_ingress[count.index].protocol
  rule_action    = var.isolated_nacl_ingress[count.index].action
  cidr_block     = var.isolated_nacl_ingress[count.index].cidr_block
  from_port      = var.isolated_nacl_ingress[count.index].from_port
  to_port        = var.isolated_nacl_ingress[count.index].to_port
}

resource "aws_network_acl_rule" "isolated_egress" {
  count          = var.create_isolated_subnets == "yes" ? length(var.isolated_nacl_egress) : 0
  network_acl_id = aws_network_acl.isolated[0].id
  rule_number    = var.isolated_nacl_egress[count.index].rule_number
  egress         = true
  protocol       = var.isolated_nacl_egress[count.index].protocol
  rule_action    = var.isolated_nacl_egress[count.index].action
  cidr_block     = var.isolated_nacl_egress[count.index].cidr_block
  from_port      = var.isolated_nacl_egress[count.index].from_port
  to_port        = var.isolated_nacl_egress[count.index].to_port
}

# -----------------------------
# ROUTE53 RESOLVER
# -----------------------------
resource "aws_route53_resolver_rule_association" "resolver" {
  count            = var.resolver_rule_ids != null ? length(var.resolver_rule_ids) : 0
  resolver_rule_id = var.resolver_rule_ids[count.index]
  vpc_id           = aws_vpc.this.id
  name             = "vpc-to-central-dns-${count.index}"
}