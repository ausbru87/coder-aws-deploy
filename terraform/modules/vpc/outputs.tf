# VPC Module Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "control_subnet_ids" {
  description = "IDs of control plane subnets"
  value       = aws_subnet.control[*].id
}

output "control_subnet_cidrs" {
  description = "CIDR blocks of control plane subnets"
  value       = aws_subnet.control[*].cidr_block
}

output "provisioner_subnet_ids" {
  description = "IDs of provisioner subnets"
  value       = aws_subnet.provisioner[*].id
}

output "provisioner_subnet_cidrs" {
  description = "CIDR blocks of provisioner subnets"
  value       = aws_subnet.provisioner[*].cidr_block
}

output "workspace_subnet_ids" {
  description = "IDs of workspace subnets"
  value       = aws_subnet.workspace[*].id
}

output "workspace_subnet_cidrs" {
  description = "CIDR blocks of workspace subnets"
  value       = aws_subnet.workspace[*].cidr_block
}

output "database_subnet_ids" {
  description = "IDs of database subnets"
  value       = aws_subnet.database[*].id
}

output "database_subnet_cidrs" {
  description = "CIDR blocks of database subnets"
  value       = aws_subnet.database[*].cidr_block
}

output "db_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = aws_db_subnet_group.main.name
}

output "nat_gateway_ids" {
  description = "IDs of NAT gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT gateways"
  value       = aws_eip.nat[*].public_ip
}

output "private_route_table_ids" {
  description = "IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "vpc_endpoint_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = var.enable_vpc_endpoints ? aws_security_group.vpc_endpoints[0].id : null
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "flow_log_group_name" {
  description = "Name of the VPC Flow Logs CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.flow_log.name
}

# Security Group Outputs

output "eks_nodes_security_group_id" {
  description = "ID of the EKS nodes security group"
  value       = aws_security_group.eks_nodes.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "nlb_security_group_id" {
  description = "ID of the NLB security group (reference)"
  value       = aws_security_group.nlb.id
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

output "workspace_nodes_security_group_id" {
  description = "ID of the workspace nodes security group with egress filtering"
  value       = aws_security_group.workspace_nodes.id
}
