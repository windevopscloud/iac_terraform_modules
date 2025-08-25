output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "public_subnet_azs" {
  description = "AZs of public subnets"
  value       = aws_subnet.public[*].availability_zone
}

output "private_subnets" {
  value = aws_subnet.private[*].id
}

output "private_subnet_azs" {
  description = "AZs of private subnets"
  value       = aws_subnet.private[*].availability_zone
}

output "isolated_subnets" {
  value = aws_subnet.isolated[*].id
}

output "isolated_subnet_azs" {
  description = "AZs of isolated subnets"
  value       = aws_subnet.isolated[*].availability_zone
}

output "igw_id" {
  value = var.create_igw == "yes" ? aws_internet_gateway.this[0].id : null
}

output "nat_gateway_ids" {
  value = var.create_nat_gateway == "yes" ? aws_nat_gateway.this[*].id : null
}

output "private_route_table_ids" {
  description = "Route table IDs for private subnets"
  value       = aws_route_table.private[*].id
}
