# VPC Module for Coder Deployment
# Creates VPC with multi-AZ subnets for control plane, provisioners, and workspaces
#
# CIDR Allocation Strategy (for 10.0.0.0/16 VPC):
# - Designed to support 3000 concurrent workspaces with 20% growth buffer
# - Separate subnets per tier for network isolation and independent scaling
# - Workspace subnets get larger allocation for pod IP requirements
#
# Requirements: 2.1, 3.1b (CIDR sizing based on max nodes and workspaces)

locals {
  # Subnet CIDR calculations based on design document
  # VPC: 10.0.0.0/16 (65,536 IPs total)
  #
  # Allocation:
  # - Public:      3 x /20 = 12,288 IPs (NAT GWs, NLB ENIs)
  # - Control:     3 x /20 = 12,288 IPs (coderd nodes)
  # - Provisioner: 3 x /20 = 12,288 IPs (provisioner nodes)
  # - Workspace:   3 x /19 = 24,576 IPs (workspace nodes - larger for 3000 workspaces)
  # - Database:    3 x /21 = 6,144 IPs  (Aurora PostgreSQL)
  # Total used: ~67,584 IPs (with some overlap in /16 space)

  # Public subnets: /20 each (4096 IPs per AZ)
  # Used for NAT Gateways and NLB ENIs
  public_cidrs = [
    cidrsubnet(var.vpc_cidr, 4, 0), # 10.0.0.0/20
    cidrsubnet(var.vpc_cidr, 4, 1), # 10.0.16.0/20
    cidrsubnet(var.vpc_cidr, 4, 2), # 10.0.32.0/20
  ]

  # Control plane subnets: /20 each (4096 IPs per AZ)
  # Used for coderd nodes
  control_cidrs = [
    cidrsubnet(var.vpc_cidr, 4, 3), # 10.0.48.0/20
    cidrsubnet(var.vpc_cidr, 4, 4), # 10.0.64.0/20
    cidrsubnet(var.vpc_cidr, 4, 5), # 10.0.80.0/20
  ]

  # Provisioner subnets: /20 each (4096 IPs per AZ)
  # Used for external provisioner nodes
  provisioner_cidrs = [
    cidrsubnet(var.vpc_cidr, 4, 6), # 10.0.96.0/20
    cidrsubnet(var.vpc_cidr, 4, 7), # 10.0.112.0/20
    cidrsubnet(var.vpc_cidr, 4, 8), # 10.0.128.0/20
  ]

  # Workspace subnets: /19 each (8192 IPs per AZ) - larger for 3000 workspaces
  # Calculation: 3000 workspaces * 4 pods avg = 12,000 IPs needed + 20% buffer
  # Using /19 per AZ provides 24,576 total IPs across 3 AZs
  # Note: /19 boundaries must be aligned (multiples of 32 in third octet)
  workspace_cidrs = [
    "10.0.160.0/19", # 10.0.160.0 - 10.0.191.255 (AZ-a)
    "10.0.192.0/19", # 10.0.192.0 - 10.0.223.255 (AZ-b)
    "10.0.224.0/19", # 10.0.224.0 - 10.0.255.255 (AZ-c)
  ]

  # Database subnets: /24 each (256 IPs per AZ)
  # Aurora only needs a few IPs per AZ for writer/reader instances
  # Using 10.0.144.x range which is between provisioner (/20 ending at 10.0.143.255)
  # and workspace (/19 starting at 10.0.160.0)
  database_cidrs = [
    "10.0.144.0/24", # 10.0.144.0 - 10.0.144.255 (AZ-a)
    "10.0.145.0/24", # 10.0.145.0 - 10.0.145.255 (AZ-b)
    "10.0.146.0/24", # 10.0.146.0 - 10.0.146.255 (AZ-c)
  ]
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb" = "1"
    Tier                     = "public"
  })
}

# Control Plane Subnets
resource "aws_subnet" "control" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.control_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name                              = "${var.project_name}-${var.environment}-control-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
    Tier                              = "control"
  })
}

# Provisioner Subnets
resource "aws_subnet" "provisioner" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.provisioner_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-provisioner-${var.availability_zones[count.index]}"
    Tier = "provisioner"
  })
}

# Workspace Subnets (larger allocation for 3000 workspaces)
# 3 subnets across AZs with /19 each for pod IP capacity
resource "aws_subnet" "workspace" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.workspace_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name                              = "${var.project_name}-${var.environment}-workspace-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
    Tier                              = "workspace"
  })
}

# Database Subnets
resource "aws_subnet" "database" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-database-${var.availability_zones[count.index]}"
    Tier = "database"
  })
}

# NAT Gateways (one per AZ for high availability)
# Requirements: 3.1, 3.1a
#
# NAT Gateways provide:
# - Egress for private subnets to reach internet
# - DERP relay support: EC2 workspaces egress through NAT to reach coderd via NLB
# - STUN support: UDP 3478 for NAT traversal discovery (direct P2P connections)
#
# Traffic flows:
# - EC2 Workspace → NAT GW → Internet → NLB → coderd (for DERP relay)
# - External clients use STUN to discover NAT mappings for direct P2P
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-nat-eip-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-nat-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
# Requirements: 3.1, 3.1a
#
# Public route table: Direct internet access via IGW
# Private route tables: Egress via NAT Gateway (one per AZ for HA)
#
# This routing enables:
# - DERP relay: EC2 workspaces can reach coderd via NAT → Internet → NLB
# - STUN: UDP traffic for NAT traversal flows through NAT Gateway
# - AWS API access: Via VPC endpoints (preferred) or NAT Gateway (fallback)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
}

resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-private-rt-${var.availability_zones[count.index]}"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "control" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.control[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "provisioner" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.provisioner[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "workspace" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.workspace[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "database" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Database Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  })
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-flow-log"
  })
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}/flow-logs"
  retention_in_days = 90

  tags = var.tags
}

resource "aws_iam_role" "flow_log" {
  name = "${var.project_name}-${var.environment}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_log" {
  name = "${var.project_name}-${var.environment}-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}
