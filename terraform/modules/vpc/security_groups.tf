# Security Groups for Coder Deployment
# Requirements: 2.1, 3.1
#
# Security group architecture:
# - Node SG: EKS nodes (control, provisioner, workspace)
# - RDS SG: Aurora PostgreSQL database
# - NLB SG: Network Load Balancer (managed by AWS LB Controller)
# - VPC Endpoints SG: AWS service endpoints (defined in endpoints.tf)

# EKS Node Security Group
# Used by all EKS node groups (control, provisioner, workspace)
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-${var.environment}-eks-nodes-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.main.id

  tags = merge(var.tags, {
    Name                                                           = "${var.project_name}-${var.environment}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Node SG - Allow all traffic between nodes (required for Kubernetes networking)
resource "aws_security_group_rule" "nodes_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Allow all traffic between EKS nodes"
}

# Node SG - Allow HTTPS from NLB (for coderd API and DERP relay)
resource "aws_security_group_rule" "nodes_nlb_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS from NLB for coderd API and DERP relay"
}

# Node SG - Allow HTTP from NLB (for health checks and redirects)
resource "aws_security_group_rule" "nodes_nlb_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP from NLB for health checks"
}

# Node SG - Allow STUN UDP for NAT traversal (direct P2P connections)
resource "aws_security_group_rule" "nodes_stun" {
  type              = "ingress"
  from_port         = 3478
  to_port           = 3478
  protocol          = "udp"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow STUN UDP for NAT traversal discovery"
}

# Node SG - Allow NodePort range for Kubernetes services
resource "aws_security_group_rule" "nodes_nodeport" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  description       = "Allow NodePort range from within VPC"
}

# Node SG - Allow kubelet API from control plane
resource "aws_security_group_rule" "nodes_kubelet" {
  type              = "ingress"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  description       = "Allow kubelet API from EKS control plane"
}

# Node SG - Allow Prometheus metrics scraping
resource "aws_security_group_rule" "nodes_prometheus" {
  type              = "ingress"
  from_port         = 2112
  to_port           = 2112
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  description       = "Allow Prometheus metrics scraping from coderd"
}

# Node SG - Allow all egress
resource "aws_security_group_rule" "nodes_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}

# RDS Security Group
# Used by Aurora PostgreSQL cluster
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS SG - Allow PostgreSQL from EKS nodes
resource "aws_security_group_rule" "rds_postgres_from_nodes" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Allow PostgreSQL from EKS nodes"
}

# RDS SG - Allow egress (for replication, backups)
resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}

# NLB Security Group (optional - NLB doesn't require SG but useful for documentation)
# Note: NLB operates at Layer 4 and doesn't use security groups directly.
# Traffic flows through to target instances which use their own security groups.
# This security group is created for reference and potential future use with
# AWS PrivateLink or other features that may require it.
resource "aws_security_group" "nlb" {
  name        = "${var.project_name}-${var.environment}-nlb-sg"
  description = "Security group for Network Load Balancer (reference)"
  vpc_id      = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-nlb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# NLB SG - Allow HTTPS from internet
resource "aws_security_group_rule" "nlb_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.nlb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS from internet"
}

# NLB SG - Allow HTTP from internet (for redirects)
resource "aws_security_group_rule" "nlb_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.nlb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP from internet for redirects"
}

# NLB SG - Allow STUN UDP
resource "aws_security_group_rule" "nlb_stun" {
  type              = "ingress"
  from_port         = 3478
  to_port           = 3478
  protocol          = "udp"
  security_group_id = aws_security_group.nlb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow STUN UDP for NAT traversal"
}

# NLB SG - Allow egress to nodes
resource "aws_security_group_rule" "nlb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.nlb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}


# Workspace Node Security Group
# Requirements: 3.1d, 3.1e
#
# Provides egress filtering for workspace nodes and access to internal resources.
# This security group is applied to workspace nodes in addition to the base EKS nodes SG.
resource "aws_security_group" "workspace_nodes" {
  name        = "${var.project_name}-${var.environment}-workspace-nodes-sg"
  description = "Security group for workspace nodes with egress filtering"
  vpc_id      = aws_vpc.main.id

  tags = merge(var.tags, {
    Name                                                           = "${var.project_name}-${var.environment}-workspace-nodes-sg"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
    Tier                                                           = "workspace"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Workspace SG - Allow all traffic between workspace nodes
resource "aws_security_group_rule" "workspace_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.workspace_nodes.id
  source_security_group_id = aws_security_group.workspace_nodes.id
  description              = "Allow all traffic between workspace nodes"
}

# Workspace SG - Allow traffic from control plane nodes
resource "aws_security_group_rule" "workspace_from_control" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.workspace_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Allow all traffic from control plane nodes"
}

# Workspace SG - Egress to VPC (internal resources)
resource "aws_security_group_rule" "workspace_egress_vpc" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.workspace_nodes.id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  description       = "Allow all egress to VPC internal resources"
}

# Workspace SG - Egress to on-premises networks (if configured)
resource "aws_security_group_rule" "workspace_egress_onprem" {
  count = length(var.onprem_cidr_blocks) > 0 ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.workspace_nodes.id
  cidr_blocks       = var.onprem_cidr_blocks
  description       = "Allow egress to on-premises networks"
}

# Workspace SG - Egress to additional AWS VPCs (if configured)
resource "aws_security_group_rule" "workspace_egress_aws_vpcs" {
  count = length(var.additional_aws_cidr_blocks) > 0 ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.workspace_nodes.id
  cidr_blocks       = var.additional_aws_cidr_blocks
  description       = "Allow egress to additional AWS VPCs"
}

# Workspace SG - Filtered egress to internet (HTTPS only by default)
# Requirements: 3.1d - Filter outbound internet traffic from workspaces
resource "aws_security_group_rule" "workspace_egress_https" {
  count = var.workspace_allow_internet_egress ? 1 : 0

  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.workspace_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS egress to internet (filtered)"
}

# Workspace SG - Allow HTTP egress (for package managers, etc.)
resource "aws_security_group_rule" "workspace_egress_http" {
  count = var.workspace_allow_internet_egress ? 1 : 0

  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.workspace_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP egress to internet (filtered)"
}

# Workspace SG - Allow SSH egress (for Git over SSH)
resource "aws_security_group_rule" "workspace_egress_ssh" {
  count = var.workspace_allow_internet_egress ? 1 : 0

  type              = "egress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.workspace_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow SSH egress for Git operations"
}

# Workspace SG - Allow DNS egress
resource "aws_security_group_rule" "workspace_egress_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  security_group_id = aws_security_group.workspace_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow DNS TCP egress"
}

resource "aws_security_group_rule" "workspace_egress_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.workspace_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow DNS UDP egress"
}


# Workspace SG - Additional allowed egress ports (configurable)
resource "aws_security_group_rule" "workspace_egress_additional" {
  for_each = toset([for port in var.workspace_allowed_egress_ports : tostring(port)])

  type              = "egress"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  protocol          = "tcp"
  security_group_id = aws_security_group.workspace_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow egress on port ${each.value}"
}
