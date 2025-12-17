# Base-EC2-GPU Infrastructure Module
# GPU-enabled EC2-based workspace infrastructure for Coder
#
# Requirements Covered:
# - 11.5: Deploy base-ec2-gpu module for GPU EC2 workspaces
# - 11.9: Support GPU instance types (g4dn, g5, p3, p4d)
# - 14.7a: GPU nodes not pre-warmed, provisioning up to 5 min
#
# This module implements the infrastructure base layer for GPU EC2 workspaces.

# =============================================================================
# Data Sources
# =============================================================================

data "aws_region" "current" {}

# Deep Learning AMI lookup
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

  # Deep Learning AMI patterns by OS
  ami_patterns = {
    "amazon-linux-2023" = "Deep Learning AMI GPU PyTorch * (Amazon Linux 2023) *"
    "ubuntu-22.04"      = "Deep Learning AMI GPU PyTorch * (Ubuntu 22.04) *"
  }

  ami_name_pattern = local.ami_patterns[var.os_type]

  # Use custom AMI if provided, otherwise use data source
  selected_ami = var.image_id != "" ? var.image_id : data.aws_ami.workspace.id

  # Parse storage from Kubernetes format (e.g., "500Gi" -> 500)
  storage_gb = tonumber(regex("^([0-9]+)", var.compute_profile.storage)[0])

  # GPU instance type mapping
  # Maps gpu_type to instance families
  gpu_instance_families = {
    "nvidia-t4"   = "g4dn" # NVIDIA T4 - inference, light training
    "nvidia-a10g" = "g5"   # NVIDIA A10G - balanced training
    "nvidia-v100" = "p3"   # NVIDIA V100 - high performance
    "nvidia-a100" = "p4d"  # NVIDIA A100 - enterprise ML
  }

  # Instance size mapping based on GPU count and compute profile
  instance_sizes = {
    "g4dn" = {
      1 = "g4dn.xlarge"   # 1x T4, 4 vCPU, 16GB
      2 = "g4dn.12xlarge" # 4x T4, 48 vCPU, 192GB
      4 = "g4dn.12xlarge" # 4x T4, 48 vCPU, 192GB
    }
    "g5" = {
      1 = "g5.xlarge"   # 1x A10G, 4 vCPU, 16GB
      2 = "g5.12xlarge" # 4x A10G, 48 vCPU, 192GB
      4 = "g5.12xlarge" # 4x A10G, 48 vCPU, 192GB
    }
    "p3" = {
      1 = "p3.2xlarge"  # 1x V100, 8 vCPU, 61GB
      4 = "p3.8xlarge"  # 4x V100, 32 vCPU, 244GB
      8 = "p3.16xlarge" # 8x V100, 64 vCPU, 488GB
    }
    "p4d" = {
      8 = "p4d.24xlarge" # 8x A100, 96 vCPU, 1152GB
    }
  }

  # Select instance family and size
  instance_family = local.gpu_instance_families[var.compute_profile.gpu_type]
  gpu_count       = var.compute_profile.gpu_count > 0 ? var.compute_profile.gpu_count : 1
  instance_type   = lookup(local.instance_sizes[local.instance_family], local.gpu_count, var.default_instance_type)

  # Common tags for all resources
  common_tags = {
    "Name"                    = local.full_name
    "coder.workspace.owner"   = var.owner
    "coder.workspace.name"    = var.workspace_name
    "coder.toolchain.name"    = var.toolchain_template.name
    "coder.toolchain.version" = var.toolchain_template.version
    "coder.base.name"         = var.base_module.name
    "coder.base.version"      = var.base_module.version
    "coder.gpu_type"          = var.compute_profile.gpu_type
    "coder.gpu_count"         = tostring(local.gpu_count)
  }

  # Runtime environment variables
  runtime_env = merge(
    {
      "CODER_WORKSPACE_NAME" = var.workspace_name
      "CODER_OWNER"          = var.owner
      "HOME"                 = "/home/coder"
      "AWS_REGION"           = data.aws_region.current.id
      "CUDA_VISIBLE_DEVICES" = "all"
    },
    var.overrides.environment_variables
  )

  # User data script with CUDA setup
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

# Verify CUDA installation (Deep Learning AMI has CUDA pre-installed)
echo "Verifying CUDA installation..."
nvidia-smi || echo "Warning: nvidia-smi failed - GPU may not be available yet"

# Set up conda environment for coder user
if [ -d /opt/conda ]; then
  echo 'source /opt/conda/etc/profile.d/conda.sh' >> /home/coder/.bashrc
  echo 'conda activate base' >> /home/coder/.bashrc
fi

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

echo "GPU Workspace ready!"
echo "GPU Type: ${var.compute_profile.gpu_type}"
echo "GPU Count: ${local.gpu_count}"
nvidia-smi
EOT
}


# =============================================================================
# Security Group for Workspace Isolation
# =============================================================================

resource "aws_security_group" "workspace" {
  name        = local.full_name
  description = "Security group for Coder GPU EC2 workspace"
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
  description       = "HTTPS for Coder agent, pip, conda"
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

  force_detach = false
}

# =============================================================================
# EC2 Instance
# Requirement 14.7a: GPU nodes not pre-warmed, provisioning up to 5 min
# =============================================================================

resource "aws_instance" "workspace" {
  ami                    = local.selected_ami
  instance_type          = local.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.workspace.id]
  iam_instance_profile   = var.instance_profile_name

  # Root volume (OS) - larger for Deep Learning AMI
  root_block_device {
    volume_size           = 100
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    encrypted             = true
    kms_key_id            = var.kms_key_id
    delete_on_termination = true
  }

  user_data = base64encode(local.user_data)

  tags = local.common_tags

  lifecycle {
    ignore_changes = [ami, user_data]
  }

  # GPU instances may take longer to provision
  timeouts {
    create = "10m"
    delete = "10m"
  }
}

# =============================================================================
# Elastic IP (optional)
# =============================================================================

resource "aws_eip" "workspace" {
  count = var.assign_elastic_ip ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.workspace.id

  tags = local.common_tags
}
