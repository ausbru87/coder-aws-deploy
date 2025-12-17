# Base-EC2-Linux Infrastructure Module
# Linux EC2-based workspace infrastructure for Coder
#
# Requirements Covered:
# - 11.5: Deploy base-ec2-linux module for EC2 workspaces
# - 11.6: Support KasmVNC for GUI workspaces
# - 11.7: Support headless workspaces
# - 11.8: Support Amazon Linux 2023, Ubuntu 22.04/24.04
# - 11a.1: Persist /home/coder directory via EBS
#
# This module implements the infrastructure base layer for Linux EC2 workspaces.

# =============================================================================
# Data Sources
# =============================================================================

data "aws_region" "current" {}

# AMI lookup for hardened images
data "aws_ami" "workspace" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = [local.ami_name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# =============================================================================
# Local Variables
# =============================================================================

locals {
  # Workspace naming
  workspace_id = "${lower(var.owner)}-${lower(var.workspace_name)}"
  full_name    = "coder-${local.workspace_id}"

  # AMI name patterns for different OS types
  ami_patterns = {
    "amazon-linux-2023" = "al2023-ami-*-kernel-*-x86_64"
    "ubuntu-22.04"      = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
    "ubuntu-24.04"      = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
  }

  ami_name_pattern = local.ami_patterns[var.os_type]

  # Use custom AMI if provided, otherwise use data source
  selected_ami = var.image_id != "" ? var.image_id : data.aws_ami.workspace.id

  # Parse storage from Kubernetes format (e.g., "100Gi" -> 100)
  storage_gb = tonumber(regex("^([0-9]+)", var.compute_profile.storage)[0])

  # Instance type mapping based on compute profile
  instance_types = {
    "2-4"   = "m5.large"   # 2 vCPU, 4GB
    "4-8"   = "m5.xlarge"  # 4 vCPU, 8GB
    "8-16"  = "m5.2xlarge" # 8 vCPU, 16GB
    "8-32"  = "m5.2xlarge" # 8 vCPU, 32GB
    "16-64" = "m5.4xlarge" # 16 vCPU, 64GB
    "32-64" = "m5.8xlarge" # 32 vCPU, 64GB
  }

  # Parse memory from Kubernetes format
  memory_gi = tonumber(regex("^([0-9]+)", var.compute_profile.memory)[0])

  # Select instance type based on CPU and memory
  instance_key  = "${var.compute_profile.cpu}-${local.memory_gi}"
  instance_type = lookup(local.instance_types, local.instance_key, var.default_instance_type)

  # Common tags for all resources
  common_tags = {
    "Name"                    = local.full_name
    "coder.workspace.owner"   = var.owner
    "coder.workspace.name"    = var.workspace_name
    "coder.toolchain.name"    = var.toolchain_template.name
    "coder.toolchain.version" = var.toolchain_template.version
    "coder.base.name"         = var.base_module.name
    "coder.base.version"      = var.base_module.version
  }

  # Runtime environment variables
  runtime_env = merge(
    {
      "CODER_WORKSPACE_NAME" = var.workspace_name
      "CODER_OWNER"          = var.owner
      "HOME"                 = "/home/coder"
      "AWS_REGION"           = data.aws_region.current.id
    },
    var.overrides.environment_variables
  )

  # User data script
  user_data = <<-EOT
#!/bin/bash
set -e

# Create coder user if not exists
if ! id -u coder &>/dev/null; then
  useradd -m -s /bin/bash -u 1000 coder
fi

# Mount EBS volume for /home/coder if persistent_home enabled
%{if var.capabilities.persistent_home}
# Wait for EBS volume to attach
while [ ! -e /dev/xvdf ]; do sleep 1; done

# Format if needed
if ! blkid /dev/xvdf; then
  mkfs.ext4 /dev/xvdf
fi

# Mount the volume
mkdir -p /home/coder
mount /dev/xvdf /home/coder
chown -R coder:coder /home/coder

# Add to fstab for persistence
echo '/dev/xvdf /home/coder ext4 defaults,nofail 0 2' >> /etc/fstab
%{endif}

# Set environment variables
%{for key, value in local.runtime_env}
echo 'export ${key}="${value}"' >> /home/coder/.bashrc
%{endfor}

# Install KasmVNC if GUI enabled
%{if var.capabilities.gui_vnc}
echo "Installing KasmVNC..."
cd /tmp
wget -q https://github.com/kasmtech/KasmVNC/releases/download/v1.2.0/kasmvncserver_jammy_1.2.0_amd64.deb
apt-get update && apt-get install -y ./kasmvncserver_jammy_1.2.0_amd64.deb xfce4 xfce4-terminal
rm kasmvncserver_jammy_1.2.0_amd64.deb

# Configure KasmVNC
su - coder -c "mkdir -p ~/.vnc"
su - coder -c "echo '${var.vnc_password}' | vncpasswd -f > ~/.vnc/passwd"
su - coder -c "chmod 600 ~/.vnc/passwd"
su - coder -c "vncserver :1 -geometry 1920x1080 -depth 24"
%{endif}

# Run Coder agent init script
${var.coder_agent_init_script}

echo "Workspace ready!"
EOT
}


# =============================================================================
# Security Group for Workspace Isolation
# =============================================================================

resource "aws_security_group" "workspace" {
  name        = local.full_name
  description = "Security group for Coder Linux EC2 workspace"
  vpc_id      = var.vpc_id

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Egress rules based on network_egress capability
resource "aws_security_group_rule" "egress_https" {
  count = var.capabilities.network_egress != "none" ? 1 : 0

  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.workspace.id
  description       = "HTTPS for Coder agent and package managers"
}

resource "aws_security_group_rule" "egress_http" {
  count = var.capabilities.network_egress == "unrestricted" ? 1 : 0

  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.workspace.id
  description       = "HTTP for package managers"
}

resource "aws_security_group_rule" "egress_dns" {
  count = var.capabilities.network_egress != "none" ? 1 : 0

  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.workspace.id
  description       = "DNS"
}

resource "aws_security_group_rule" "egress_all" {
  count = var.capabilities.network_egress == "unrestricted" ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.workspace.id
  description       = "Unrestricted egress"
}

# =============================================================================
# EBS Volume for /home/coder Persistence
# Requirement 11a.1: Persist user's /home/coder directory
# =============================================================================

resource "aws_ebs_volume" "home" {
  count = var.capabilities.persistent_home ? 1 : 0

  availability_zone = var.availability_zone
  size              = local.storage_gb
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true
  kms_key_id        = var.kms_key_id

  tags = merge(local.common_tags, {
    "Name" = "${local.full_name}-home"
  })
}

resource "aws_volume_attachment" "home" {
  count = var.capabilities.persistent_home ? 1 : 0

  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.home[0].id
  instance_id = aws_instance.workspace.id

  # Don't force detach to prevent data loss
  force_detach = false
}

# =============================================================================
# EC2 Instance
# =============================================================================

resource "aws_instance" "workspace" {
  ami                    = local.selected_ami
  instance_type          = local.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.workspace.id]
  iam_instance_profile   = var.instance_profile_name

  # Root volume (OS)
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.kms_key_id
    delete_on_termination = true
  }

  user_data = base64encode(local.user_data)

  tags = local.common_tags

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# =============================================================================
# Elastic IP (optional, for consistent addressing)
# =============================================================================

resource "aws_eip" "workspace" {
  count = var.assign_elastic_ip ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.workspace.id

  tags = local.common_tags
}
