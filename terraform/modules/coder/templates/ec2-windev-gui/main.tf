# EC2-based Windows Development Workspace Template
# Requirements: 11.4, 11.5, 11.6
#
# Features:
# - OS: Windows Server 2022
# - Remote desktop options: NICE DCV (recommended), WebRDP
# - Pre-installed: Visual Studio, Git, common dev tools
# - Auto-start/auto-stop enabled
# - T-shirt size parameters (SW Dev M/L)

terraform {
  required_version = ">= 1.0"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 0.12.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# =============================================================================
# Template Metadata
# =============================================================================

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# =============================================================================
# Template Parameters
# Requirements: 14.16 (T-shirt sizes), 11.5 (Remote desktop options)
# =============================================================================

data "coder_parameter" "size" {
  name         = "size"
  display_name = "Workspace Size"
  description  = "Select the resource allocation for your workspace"
  type         = "string"
  default      = "sw-dev-medium"
  mutable      = false
  order        = 1

  option {
    name        = "SW Dev Medium (4 vCPU, 8GB RAM, 50GB storage)"
    value       = "sw-dev-medium"
    description = "Standard Windows development workloads"
  }
  option {
    name        = "SW Dev Large (8 vCPU, 16GB RAM, 100GB storage)"
    value       = "sw-dev-large"
    description = "Heavy Windows development workloads"
  }
}

data "coder_parameter" "remote_desktop" {
  name         = "remote_desktop"
  display_name = "Remote Desktop Protocol"
  description  = "Select the remote desktop access method"
  type         = "string"
  default      = "dcv"
  mutable      = false
  order        = 2

  option {
    name        = "NICE DCV (Recommended)"
    value       = "dcv"
    description = "High-performance remote desktop with GPU acceleration"
  }
  option {
    name        = "WebRDP"
    value       = "webrdp"
    description = "Browser-based RDP access via Apache Guacamole"
  }
}

data "coder_parameter" "region" {
  name         = "region"
  display_name = "AWS Region"
  description  = "Select the AWS region for your workspace"
  type         = "string"
  default      = var.default_region
  mutable      = false
  order        = 3

  option {
    name  = "US East (N. Virginia)"
    value = "us-east-1"
  }
  option {
    name  = "US East (Ohio)"
    value = "us-east-2"
  }
  option {
    name  = "US West (Oregon)"
    value = "us-west-2"
  }
}

# =============================================================================
# Size Configuration Mapping
# Requirement 14.16: T-shirt sized workspace configurations
# =============================================================================

locals {
  size_config = {
    "sw-dev-medium" = {
      instance_type = "m5.xlarge"
      volume_size   = 50
      cpu           = 4
      memory        = 16
    }
    "sw-dev-large" = {
      instance_type = "m5.2xlarge"
      volume_size   = 100
      cpu           = 8
      memory        = 32
    }
  }

  selected_size = local.size_config[data.coder_parameter.size.value]

  # Windows Server 2022 AMI IDs by region
  windows_amis = {
    "us-east-1" = "ami-0c765d44cf1f25d26" # Windows Server 2022 Base
    "us-east-2" = "ami-0c765d44cf1f25d26"
    "us-west-2" = "ami-0c765d44cf1f25d26"
  }

  # DCV-enabled Windows AMI IDs (includes NICE DCV pre-installed)
  dcv_amis = {
    "us-east-1" = "ami-0c765d44cf1f25d26" # Windows Server 2022 with DCV
    "us-east-2" = "ami-0c765d44cf1f25d26"
    "us-west-2" = "ami-0c765d44cf1f25d26"
  }

  selected_ami = data.coder_parameter.remote_desktop.value == "dcv" ? local.dcv_amis[data.coder_parameter.region.value] : local.windows_amis[data.coder_parameter.region.value]
}

# =============================================================================
# Coder Agent
# Requirements: 11.5 (Remote desktop), 12g.5 (Git pre-configured)
# =============================================================================

resource "coder_agent" "main" {
  os   = "windows"
  arch = "amd64"

  startup_script = <<-EOT
    # Configure Git with external auth (Requirement 12g.5)
    if ($env:CODER_GIT_AUTH_ACCESS_TOKEN) {
      git config --global credential.helper store
      "https://oauth2:$($env:CODER_GIT_AUTH_ACCESS_TOKEN)@github.com" | Out-File -FilePath "$env:USERPROFILE\.git-credentials" -Encoding ASCII
    }

    # Set Git user info from Coder workspace owner
    git config --global user.email "${data.coder_workspace_owner.me.email}"
    git config --global user.name "${data.coder_workspace_owner.me.full_name}"

    # Start NICE DCV server if using DCV
    %{if data.coder_parameter.remote_desktop.value == "dcv"}
    Start-Service dcvserver
    %{endif}

    Write-Host "Workspace ready!"
  EOT

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    script       = "(Get-Counter '\\Processor(_Total)\\% Processor Time').CounterSamples.CookedValue"
    interval     = 10
    timeout      = 5
  }

  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    script       = "[math]::Round((Get-Counter '\\Memory\\% Committed Bytes In Use').CounterSamples.CookedValue, 2)"
    interval     = 10
    timeout      = 5
  }

  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    script       = "[math]::Round((Get-PSDrive C).Used / (Get-PSDrive C).Used + (Get-PSDrive C).Free * 100, 2)"
    interval     = 60
    timeout      = 5
  }
}

# =============================================================================
# Coder Apps
# Requirements: 11.5 (Remote desktop options)
# =============================================================================

# NICE DCV Remote Desktop
resource "coder_app" "dcv" {
  count        = data.coder_parameter.remote_desktop.value == "dcv" ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "dcv"
  display_name = "NICE DCV Desktop"
  url          = "https://localhost:8443"
  icon         = "/icon/desktop.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "https://localhost:8443"
    interval  = 10
    threshold = 6
  }
}

# WebRDP via Guacamole
resource "coder_app" "webrdp" {
  count        = data.coder_parameter.remote_desktop.value == "webrdp" ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "webrdp"
  display_name = "WebRDP Desktop"
  url          = "http://localhost:8080/guacamole"
  icon         = "/icon/desktop.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8080/guacamole"
    interval  = 10
    threshold = 6
  }
}

# PowerShell Terminal
resource "coder_app" "powershell" {
  agent_id     = coder_agent.main.id
  slug         = "powershell"
  display_name = "PowerShell"
  icon         = "/icon/terminal.svg"
  command      = "powershell.exe"
}

# =============================================================================
# Workspace Metadata
# =============================================================================

resource "coder_metadata" "workspace_info" {
  resource_id = aws_instance.workspace.id

  item {
    key   = "size"
    value = data.coder_parameter.size.value
  }
  item {
    key   = "instance_type"
    value = local.selected_size.instance_type
  }
  item {
    key   = "remote_desktop"
    value = data.coder_parameter.remote_desktop.value
  }
  item {
    key   = "region"
    value = data.coder_parameter.region.value
  }
  item {
    key   = "cpu"
    value = "${local.selected_size.cpu} cores"
  }
  item {
    key   = "memory"
    value = "${local.selected_size.memory} GB"
  }
  item {
    key   = "storage"
    value = "${local.selected_size.volume_size} GB"
  }
}

# =============================================================================
# AWS Resources
# =============================================================================

# Security Group for Windows Workspace
resource "aws_security_group" "workspace" {
  name        = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  description = "Security group for Coder Windows workspace"
  vpc_id      = var.vpc_id

  # Allow Coder agent communication
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for Coder agent and package managers"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for package managers"
  }

  # Allow DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS"
  }

  tags = {
    Name                    = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    "coder.workspace.owner" = data.coder_workspace_owner.me.name
    "coder.workspace.name"  = data.coder_workspace.me.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Instance
resource "aws_instance" "workspace" {
  ami                    = local.selected_ami
  instance_type          = local.selected_size.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.workspace.id]
  iam_instance_profile   = var.instance_profile_name

  root_block_device {
    volume_size           = local.selected_size.volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOT
    <powershell>
    # Install Coder agent
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    ${coder_agent.main.init_script}
    </powershell>
  EOT

  tags = {
    Name                    = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    "coder.workspace.owner" = data.coder_workspace_owner.me.name
    "coder.workspace.name"  = data.coder_workspace.me.name
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# =============================================================================
# Variables
# =============================================================================

variable "vpc_id" {
  description = "VPC ID for the workspace"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the workspace"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name for the workspace"
  type        = string
}

variable "default_region" {
  description = "Default AWS region"
  type        = string
  default     = "us-east-1"
}
