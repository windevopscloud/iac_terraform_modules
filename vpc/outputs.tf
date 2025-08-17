output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "private_subnets" {
  value = aws_subnet.private[*].id
}

output "isolated_subnets" {
  value = aws_subnet.isolated[*].id
}

output "igw_id" {
  value = var.create_igw == "yes" ? aws_internet_gateway.this[0].id : null
}

output "nat_gateway_id" {
  value = var.create_nat_gateway == "yes" ? aws_nat_gateway.this[0].id : null
}
