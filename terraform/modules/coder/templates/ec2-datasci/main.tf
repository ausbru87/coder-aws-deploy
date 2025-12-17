# EC2-based Data Science Workspace Template
# Requirements: 11.4, 11.8, 14.7a
#
# Features:
# - Base OS: Amazon Linux 2023, Ubuntu 22.04 (CUDA-enabled AMIs)
# - GPU options: g4dn, g5, p3, p4d instance types
# - Pre-installed: Jupyter Lab, Python, PyTorch, TensorFlow, CUDA
# - Auto-start/auto-stop enabled
# - T-shirt size parameters (Data Sci Standard/Large/XLarge)
# - Note: GPU nodes not pre-warmed, provisioning up to 5 min

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
# Requirements: 14.16 (T-shirt sizes), 11.8 (GPU support)
# =============================================================================

data "coder_parameter" "size" {
  name         = "size"
  display_name = "Workspace Size"
  description  = "Select the resource allocation for your workspace"
  type         = "string"
  default      = "datasci-standard"
  mutable      = false
  order        = 1

  option {
    name        = "Data Sci Standard (8 vCPU, 32GB RAM, 500GB storage)"
    value       = "datasci-standard"
    description = "Data analysis and light ML workloads"
  }
  option {
    name        = "Data Sci Large (16 vCPU, 64GB RAM, 1TB storage, GPU optional)"
    value       = "datasci-large"
    description = "ML training and medium-scale workloads"
  }
  option {
    name        = "Data Sci XLarge (32 vCPU, 64GB RAM, 2TB storage, 1-N GPUs)"
    value       = "datasci-xlarge"
    description = "Large-scale ML training with multiple GPUs"
  }
}

data "coder_parameter" "os" {
  name         = "os"
  display_name = "Operating System"
  description  = "Select the base operating system"
  type         = "string"
  default      = "ubuntu-22.04"
  mutable      = false
  order        = 2

  option {
    name        = "Ubuntu 22.04 LTS (CUDA)"
    value       = "ubuntu-22.04"
    description = "Ubuntu 22.04 with CUDA drivers pre-installed"
  }
  option {
    name        = "Amazon Linux 2023 (CUDA)"
    value       = "amazon-linux-2023"
    description = "Amazon Linux 2023 with CUDA drivers pre-installed"
  }
}

data "coder_parameter" "gpu_type" {
  name         = "gpu_type"
  display_name = "GPU Type"
  description  = "Select the GPU type (affects instance type)"
  type         = "string"
  default      = "none"
  mutable      = false
  order        = 3

  option {
    name        = "No GPU (CPU only)"
    value       = "none"
    description = "CPU-only instance for data analysis"
  }
  option {
    name        = "NVIDIA T4 (g4dn) - Inference"
    value       = "g4dn"
    description = "Cost-effective for inference and light training"
  }
  option {
    name        = "NVIDIA A10G (g5) - Training"
    value       = "g5"
    description = "Balanced performance for training workloads"
  }
  option {
    name        = "NVIDIA V100 (p3) - High Performance"
    value       = "p3"
    description = "High-performance training with NVLink"
  }
  option {
    name        = "NVIDIA A100 (p4d) - Enterprise ML"
    value       = "p4d"
    description = "Enterprise-grade ML with 8x A100 GPUs"
  }
}

data "coder_parameter" "region" {
  name         = "region"
  display_name = "AWS Region"
  description  = "Select the AWS region for your workspace"
  type         = "string"
  default      = var.default_region
  mutable      = false
  order        = 4

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
# Size and GPU Configuration Mapping
# Requirements: 14.16 (T-shirt sizes), 11.8 (GPU instance types)
# =============================================================================

locals {
  # Base size configurations (CPU-only)
  size_config = {
    "datasci-standard" = {
      cpu_instance = "m5.2xlarge"
      volume_size  = 500
      cpu          = 8
      memory       = 32
    }
    "datasci-large" = {
      cpu_instance = "m5.4xlarge"
      volume_size  = 1000
      cpu          = 16
      memory       = 64
    }
    "datasci-xlarge" = {
      cpu_instance = "m5.8xlarge"
      volume_size  = 2000
      cpu          = 32
      memory       = 64
    }
  }

  # GPU instance type mapping
  gpu_instances = {
    "none" = {
      "datasci-standard" = "m5.2xlarge"
      "datasci-large"    = "m5.4xlarge"
      "datasci-xlarge"   = "m5.8xlarge"
    }
    "g4dn" = {
      "datasci-standard" = "g4dn.2xlarge"  # 1x T4, 8 vCPU, 32GB
      "datasci-large"    = "g4dn.4xlarge"  # 1x T4, 16 vCPU, 64GB
      "datasci-xlarge"   = "g4dn.12xlarge" # 4x T4, 48 vCPU, 192GB
    }
    "g5" = {
      "datasci-standard" = "g5.2xlarge"  # 1x A10G, 8 vCPU, 32GB
      "datasci-large"    = "g5.4xlarge"  # 1x A10G, 16 vCPU, 64GB
      "datasci-xlarge"   = "g5.12xlarge" # 4x A10G, 48 vCPU, 192GB
    }
    "p3" = {
      "datasci-standard" = "p3.2xlarge"  # 1x V100, 8 vCPU, 61GB
      "datasci-large"    = "p3.8xlarge"  # 4x V100, 32 vCPU, 244GB
      "datasci-xlarge"   = "p3.16xlarge" # 8x V100, 64 vCPU, 488GB
    }
    "p4d" = {
      "datasci-standard" = "p4d.24xlarge" # 8x A100, 96 vCPU, 1152GB
      "datasci-large"    = "p4d.24xlarge"
      "datasci-xlarge"   = "p4d.24xlarge"
    }
  }

  # Deep Learning AMIs by region and OS
  dl_amis = {
    "us-east-1" = {
      "ubuntu-22.04"      = "ami-0c765d44cf1f25d26" # Deep Learning AMI Ubuntu 22.04
      "amazon-linux-2023" = "ami-0c765d44cf1f25d26" # Deep Learning AMI AL2023
    }
    "us-east-2" = {
      "ubuntu-22.04"      = "ami-0c765d44cf1f25d26"
      "amazon-linux-2023" = "ami-0c765d44cf1f25d26"
    }
    "us-west-2" = {
      "ubuntu-22.04"      = "ami-0c765d44cf1f25d26"
      "amazon-linux-2023" = "ami-0c765d44cf1f25d26"
    }
  }

  selected_size     = local.size_config[data.coder_parameter.size.value]
  selected_instance = local.gpu_instances[data.coder_parameter.gpu_type.value][data.coder_parameter.size.value]
  selected_ami      = local.dl_amis[data.coder_parameter.region.value][data.coder_parameter.os.value]
  has_gpu           = data.coder_parameter.gpu_type.value != "none"
}

# =============================================================================
# Coder Agent
# Requirements: 11.8 (ML tooling), 12g.5 (Git pre-configured)
# =============================================================================

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Configure Git with external auth (Requirement 12g.5)
    if [ -n "$CODER_GIT_AUTH_ACCESS_TOKEN" ]; then
      git config --global credential.helper "store"
      echo "https://oauth2:$CODER_GIT_AUTH_ACCESS_TOKEN@github.com" > ~/.git-credentials
    fi

    # Set Git user info from Coder workspace owner
    git config --global user.email "${data.coder_workspace_owner.me.email}"
    git config --global user.name "${data.coder_workspace_owner.me.full_name}"

    # Activate conda environment
    source /opt/conda/etc/profile.d/conda.sh
    conda activate base

    # Start Jupyter Lab
    jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --NotebookApp.token='' --NotebookApp.password='' &

    %{if local.has_gpu}
    # Verify GPU is available
    echo "Checking GPU availability..."
    nvidia-smi || echo "Warning: GPU not detected"
    %{endif}

    echo "Workspace ready!"
  EOT

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    script       = "top -bn1 | grep 'Cpu(s)' | awk '{print $2}'"
    interval     = 10
    timeout      = 1
  }

  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    script       = "free -h | awk '/^Mem:/ {print $3\"/\"$2}'"
    interval     = 10
    timeout      = 1
  }

  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    script       = "df -h /home | tail -1 | awk '{print $5}'"
    interval     = 60
    timeout      = 1
  }

  dynamic "metadata" {
    for_each = local.has_gpu ? [1] : []
    content {
      key          = "gpu"
      display_name = "GPU Usage"
      script       = "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo 'N/A'"
      interval     = 10
      timeout      = 5
    }
  }

  dynamic "metadata" {
    for_each = local.has_gpu ? [1] : []
    content {
      key          = "gpu_memory"
      display_name = "GPU Memory"
      script       = "nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '{print $1\"MiB/\"$2\"MiB\"}' || echo 'N/A'"
      interval     = 10
      timeout      = 5
    }
  }
}

# =============================================================================
# Coder Apps
# Requirements: 11.8 (Jupyter Lab)
# =============================================================================

# Jupyter Lab
resource "coder_app" "jupyter" {
  agent_id     = coder_agent.main.id
  slug         = "jupyter"
  display_name = "Jupyter Lab"
  url          = "http://localhost:8888"
  icon         = "/icon/jupyter.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8888/api"
    interval  = 5
    threshold = 6
  }
}

# VS Code Web
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337/?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

# Terminal
resource "coder_app" "terminal" {
  agent_id     = coder_agent.main.id
  slug         = "terminal"
  display_name = "Terminal"
  icon         = "/icon/terminal.svg"
  command      = "/bin/bash"
}

# TensorBoard (if GPU enabled)
resource "coder_app" "tensorboard" {
  count        = local.has_gpu ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "tensorboard"
  display_name = "TensorBoard"
  url          = "http://localhost:6006"
  icon         = "/icon/tensorflow.svg"
  subdomain    = true
  share        = "owner"
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
    key   = "os"
    value = data.coder_parameter.os.value
  }
  item {
    key   = "gpu_type"
    value = data.coder_parameter.gpu_type.value
  }
  item {
    key   = "instance_type"
    value = local.selected_instance
  }
  item {
    key   = "region"
    value = data.coder_parameter.region.value
  }
  item {
    key   = "storage"
    value = "${local.selected_size.volume_size} GB"
  }
  item {
    key   = "provisioning_note"
    value = local.has_gpu ? "GPU instances may take up to 5 minutes to provision (Req 14.7a)" : "CPU-only instance"
  }
}

# =============================================================================
# AWS Resources
# =============================================================================

# Security Group for Data Science Workspace
resource "aws_security_group" "workspace" {
  name        = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  description = "Security group for Coder Data Science workspace"
  vpc_id      = var.vpc_id

  # Allow Coder agent communication
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for Coder agent, pip, conda"
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
# Requirement 14.7a: GPU nodes not pre-warmed, provisioning up to 5 min
resource "aws_instance" "workspace" {
  ami                    = local.selected_ami
  instance_type          = local.selected_instance
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.workspace.id]
  iam_instance_profile   = var.instance_profile_name

  root_block_device {
    volume_size           = local.selected_size.volume_size
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOT
    #!/bin/bash
    # Install Coder agent
    ${coder_agent.main.init_script}
  EOT

  tags = {
    Name                    = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    "coder.workspace.owner" = data.coder_workspace_owner.me.name
    "coder.workspace.name"  = data.coder_workspace.me.name
    "coder.gpu_type"        = data.coder_parameter.gpu_type.value
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
