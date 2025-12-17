# Base-EC2-Windows Infrastructure Module
# Windows EC2-based workspace infrastructure for Coder
#
# Requirements Covered:
# - 11.5: Deploy base-ec2-windows module for Windows EC2 workspaces
# - 11.6: Support NICE DCV (recommended) or WebRDP for GUI access
# - 11.7: Support Windows Server 2022
#
# This module implements the infrastructure base layer for Windows EC2 workspaces.

# =============================================================================
# Data Sources
# =============================================================================

data "aws_region" "current" {}

# AMI lookup for Windows Server 2022
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

  # AMI name patterns - Windows Server 2022 with DCV or standard
  ami_patterns = {
    "dcv"    = "Windows_Server-2022-English-Full-Base-*"
    "webrdp" = "Windows_Server-2022-English-Full-Base-*"
  }

  ami_name_pattern = local.ami_patterns[var.remote_desktop_type]

  # Use custom AMI if provided, otherwise use data source
  selected_ami = var.image_id != "" ? var.image_id : data.aws_ami.workspace.id

  # Parse storage from Kubernetes format (e.g., "100Gi" -> 100)
  storage_gb = tonumber(regex("^([0-9]+)", var.compute_profile.storage)[0])

  # Instance type mapping based on compute profile
  instance_types = {
    "4-8"  = "m5.xlarge"  # 4 vCPU, 16GB (Windows needs more memory)
    "4-16" = "m5.xlarge"  # 4 vCPU, 16GB
    "8-16" = "m5.2xlarge" # 8 vCPU, 32GB
    "8-32" = "m5.2xlarge" # 8 vCPU, 32GB
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
      "AWS_REGION"           = data.aws_region.current.id
    },
    var.overrides.environment_variables
  )

  # PowerShell user data script
  user_data = <<-EOT
<powershell>
# Set execution policy
Set-ExecutionPolicy Bypass -Scope Process -Force

# Create coder user
$Password = ConvertTo-SecureString "${var.windows_password}" -AsPlainText -Force
New-LocalUser -Name "coder" -Password $Password -FullName "Coder User" -Description "Coder workspace user"
Add-LocalGroupMember -Group "Administrators" -Member "coder"
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "coder"

# Set environment variables
%{for key, value in local.runtime_env}
[Environment]::SetEnvironmentVariable("${key}", "${value}", "Machine")
%{endfor}

# Install NICE DCV if using DCV
%{if var.remote_desktop_type == "dcv"}
Write-Host "Installing NICE DCV..."
$dcvUrl = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi"
$dcvInstaller = "$env:TEMP\nice-dcv-server.msi"
Invoke-WebRequest -Uri $dcvUrl -OutFile $dcvInstaller
Start-Process msiexec.exe -ArgumentList "/i $dcvInstaller /quiet /norestart" -Wait

# Configure DCV
$dcvConfig = @"
[display]
target-fps = 60
[connectivity]
enable-quic-frontend = true
"@
$dcvConfig | Out-File -FilePath "C:\Program Files\NICE\DCV\Server\conf\dcv.conf" -Encoding ASCII

# Start DCV service
Start-Service dcvserver
Set-Service dcvserver -StartupType Automatic

# Create DCV session
& "C:\Program Files\NICE\DCV\Server\bin\dcv.exe" create-session --type=console --owner coder coder-session
%{endif}

# Install WebRDP (Guacamole) if using WebRDP
%{if var.remote_desktop_type == "webrdp"}
Write-Host "Configuring WebRDP access..."
# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
%{endif}

# Initialize EBS volume for user data if persistent_home enabled
%{if var.capabilities.persistent_home}
Write-Host "Configuring persistent storage..."
# Wait for volume to attach
$diskNumber = 1
$maxWait = 60
$waited = 0
while (-not (Get-Disk -Number $diskNumber -ErrorAction SilentlyContinue) -and $waited -lt $maxWait) {
    Start-Sleep -Seconds 1
    $waited++
}

# Initialize and format if needed
$disk = Get-Disk -Number $diskNumber
if ($disk.PartitionStyle -eq 'RAW') {
    Initialize-Disk -Number $diskNumber -PartitionStyle GPT
    New-Partition -DiskNumber $diskNumber -UseMaximumSize -DriveLetter D
    Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel "CoderData" -Confirm:$false
}

# Create user profile directory on D:
New-Item -ItemType Directory -Path "D:\Users\coder" -Force
%{endif}

# Run Coder agent init script
${var.coder_agent_init_script}

Write-Host "Workspace ready!"
</powershell>
EOT
}


# =============================================================================
# Security Group for Workspace Isolation
# =============================================================================

resource "aws_security_group" "workspace" {
  name        = local.full_name
  description = "Security group for Coder Windows EC2 workspace"
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
# EBS Volume for User Data Persistence
# =============================================================================

resource "aws_ebs_volume" "data" {
  count = var.capabilities.persistent_home ? 1 : 0

  availability_zone = var.availability_zone
  size              = local.storage_gb
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true
  kms_key_id        = var.kms_key_id

  tags = merge(local.common_tags, {
    "Name" = "${local.full_name}-data"
  })
}

resource "aws_volume_attachment" "data" {
  count = var.capabilities.persistent_home ? 1 : 0

  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.data[0].id
  instance_id = aws_instance.workspace.id

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

  # Root volume (OS) - Windows needs larger root
  root_block_device {
    volume_size           = 50
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
# Elastic IP (optional)
# =============================================================================

resource "aws_eip" "workspace" {
  count = var.assign_elastic_ip ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.workspace.id

  tags = local.common_tags
}
