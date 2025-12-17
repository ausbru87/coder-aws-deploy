# Network ACLs for Coder Deployment
# Requirements: 3.1d, 3.1e
#
# Network ACLs provide stateless filtering at the subnet level.
# They act as an additional layer of defense beyond security groups.
#
# Note: NACLs are stateless, so both inbound and outbound rules are required
# for bidirectional traffic. Ephemeral ports (1024-65535) must be allowed
# for return traffic.

# Workspace Subnet Network ACL
# Provides additional egress filtering for workspace subnets
resource "aws_network_acl" "workspace" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.workspace[*].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-workspace-nacl"
    Tier = "workspace"
  })
}

# Workspace NACL - Allow all inbound from VPC
resource "aws_network_acl_rule" "workspace_inbound_vpc" {
  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
}

# Workspace NACL - Allow inbound ephemeral ports (return traffic from internet)
resource "aws_network_acl_rule" "workspace_inbound_ephemeral" {
  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# Workspace NACL - Allow inbound UDP ephemeral ports (DNS responses, etc.)
resource "aws_network_acl_rule" "workspace_inbound_ephemeral_udp" {
  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 210
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# Workspace NACL - Allow all outbound to VPC (internal resources)
resource "aws_network_acl_rule" "workspace_outbound_vpc" {
  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
}

# Workspace NACL - Allow outbound HTTPS to internet
resource "aws_network_acl_rule" "workspace_outbound_https" {
  count = var.workspace_allow_internet_egress ? 1 : 0

  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# Workspace NACL - Allow outbound HTTP to internet
resource "aws_network_acl_rule" "workspace_outbound_http" {
  count = var.workspace_allow_internet_egress ? 1 : 0

  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 210
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# Workspace NACL - Allow outbound SSH to internet (Git)
resource "aws_network_acl_rule" "workspace_outbound_ssh" {
  count = var.workspace_allow_internet_egress ? 1 : 0

  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 220
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

# Workspace NACL - Allow outbound DNS TCP
resource "aws_network_acl_rule" "workspace_outbound_dns_tcp" {
  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 230
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# Workspace NACL - Allow outbound DNS UDP
resource "aws_network_acl_rule" "workspace_outbound_dns_udp" {
  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 240
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# Workspace NACL - Allow outbound ephemeral ports (for return traffic)
resource "aws_network_acl_rule" "workspace_outbound_ephemeral" {
  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 300
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# Workspace NACL - Allow outbound to on-premises networks
resource "aws_network_acl_rule" "workspace_outbound_onprem" {
  count = length(var.onprem_cidr_blocks)

  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 400 + count.index
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.onprem_cidr_blocks[count.index]
}

# Workspace NACL - Allow inbound from on-premises networks
resource "aws_network_acl_rule" "workspace_inbound_onprem" {
  count = length(var.onprem_cidr_blocks)

  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 300 + count.index
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.onprem_cidr_blocks[count.index]
}

# Workspace NACL - Allow outbound to additional AWS VPCs
resource "aws_network_acl_rule" "workspace_outbound_aws_vpcs" {
  count = length(var.additional_aws_cidr_blocks)

  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 500 + count.index
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.additional_aws_cidr_blocks[count.index]
}

# Workspace NACL - Allow inbound from additional AWS VPCs
resource "aws_network_acl_rule" "workspace_inbound_aws_vpcs" {
  count = length(var.additional_aws_cidr_blocks)

  network_acl_id = aws_network_acl.workspace.id
  rule_number    = 400 + count.index
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.additional_aws_cidr_blocks[count.index]
}
