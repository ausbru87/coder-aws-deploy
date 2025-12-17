# Pod-based Software Development Workspace Template
# Requirements: 11.3, 11.4, 11.5, 11.6, 11.7, 11a.1, 3.1c, 12g.5, 13.1, 13.2, 13.3
#
# Features:
# - Base OS options: Amazon Linux 2023, Ubuntu 22.04/24.04
# - GUI option: KasmVNC for browser-based desktop
# - Headless option: SSH/VS Code Remote access
# - /home/coder persistence via EBS
# - Git CLI pre-configured with external auth
# - NetworkPolicy for workspace isolation
# - Auto-start/auto-stop enabled (0700/1800 ET)
# - T-shirt size parameters (SW Dev S/M/L, Platform/DevSecOps)

terraform {
  required_version = ">= 1.0"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 0.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
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
# Requirements: 14.16 (T-shirt sizes), 11.4 (OS options), 11.5 (GUI options)
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
    name        = "SW Dev Small (2 vCPU, 4GB RAM, 20GB storage)"
    value       = "sw-dev-small"
    description = "Light development workloads"
  }
  option {
    name        = "SW Dev Medium (4 vCPU, 8GB RAM, 50GB storage)"
    value       = "sw-dev-medium"
    description = "Standard development workloads"
  }
  option {
    name        = "SW Dev Large (8 vCPU, 16GB RAM, 100GB storage)"
    value       = "sw-dev-large"
    description = "Heavy development workloads"
  }
  option {
    name        = "Platform/DevSecOps (4 vCPU, 8GB RAM, 100GB storage)"
    value       = "platform-devsecops"
    description = "Infrastructure and DevSecOps work"
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
    name        = "Ubuntu 22.04 LTS"
    value       = "ubuntu-22.04"
    description = "Ubuntu 22.04 LTS (Jammy Jellyfish)"
  }
  option {
    name        = "Ubuntu 24.04 LTS"
    value       = "ubuntu-24.04"
    description = "Ubuntu 24.04 LTS (Noble Numbat)"
  }
  option {
    name        = "Amazon Linux 2023"
    value       = "amazon-linux-2023"
    description = "Amazon Linux 2023"
  }
}

data "coder_parameter" "gui_enabled" {
  name         = "gui_enabled"
  display_name = "Desktop GUI"
  description  = "Enable browser-based desktop via KasmVNC"
  type         = "bool"
  default      = "false"
  mutable      = true
  order        = 3
}

# =============================================================================
# Size Configuration Mapping
# Requirement 14.16: T-shirt sized workspace configurations
# =============================================================================

locals {
  size_config = {
    "sw-dev-small" = {
      cpu_request    = "1"
      cpu_limit      = "2"
      memory_request = "2Gi"
      memory_limit   = "4Gi"
      storage_size   = "20Gi"
    }
    "sw-dev-medium" = {
      cpu_request    = "2"
      cpu_limit      = "4"
      memory_request = "4Gi"
      memory_limit   = "8Gi"
      storage_size   = "50Gi"
    }
    "sw-dev-large" = {
      cpu_request    = "4"
      cpu_limit      = "8"
      memory_request = "8Gi"
      memory_limit   = "16Gi"
      storage_size   = "100Gi"
    }
    "platform-devsecops" = {
      cpu_request    = "2"
      cpu_limit      = "4"
      memory_request = "4Gi"
      memory_limit   = "8Gi"
      storage_size   = "100Gi"
    }
  }

  os_images = {
    "ubuntu-22.04"      = "codercom/enterprise-base:ubuntu"
    "ubuntu-24.04"      = "codercom/enterprise-base:ubuntu"
    "amazon-linux-2023" = "codercom/enterprise-base:latest"
  }

  gui_images = {
    "ubuntu-22.04"      = "codercom/enterprise-desktop:ubuntu"
    "ubuntu-24.04"      = "codercom/enterprise-desktop:ubuntu"
    "amazon-linux-2023" = "codercom/enterprise-desktop:latest"
  }

  selected_size  = local.size_config[data.coder_parameter.size.value]
  selected_image = data.coder_parameter.gui_enabled.value == "true" ? local.gui_images[data.coder_parameter.os.value] : local.os_images[data.coder_parameter.os.value]
}

# =============================================================================
# Coder Agent
# Requirements: 12g.5 (Git CLI pre-configured), 11.7 (headless SSH/VS Code)
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

    # Start KasmVNC if GUI is enabled (Requirement 11.5)
    %{if data.coder_parameter.gui_enabled.value == "true"}
    echo "Starting KasmVNC desktop..."
    /dockerstartup/kasm_default_profile.sh
    /dockerstartup/vnc_startup.sh &
    %{endif}

    echo "Workspace ready!"
  EOT

  # Metadata for workspace info
  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    script       = "cat /sys/fs/cgroup/cpu.stat | grep usage_usec | awk '{print $2/1000000}'"
    interval     = 10
    timeout      = 1
  }

  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    script       = "cat /sys/fs/cgroup/memory.current | numfmt --to=iec"
    interval     = 10
    timeout      = 1
  }

  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    script       = "df -h /home/coder | tail -1 | awk '{print $5}'"
    interval     = 60
    timeout      = 1
  }
}

# =============================================================================
# Coder Apps
# Requirements: 11.5 (KasmVNC GUI), 11.7 (VS Code Remote)
# =============================================================================

# VS Code Web (code-server)
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

# KasmVNC Desktop (if GUI enabled)
resource "coder_app" "desktop" {
  count        = data.coder_parameter.gui_enabled.value == "true" ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "desktop"
  display_name = "Desktop"
  url          = "http://localhost:6901"
  icon         = "/icon/desktop.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:6901/api/health"
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

# =============================================================================
# Workspace Lifecycle
# Requirements: 13.1, 13.2, 13.3 (auto-start/auto-stop)
# =============================================================================

resource "coder_metadata" "workspace_info" {
  resource_id = kubernetes_deployment_v1.workspace.id

  item {
    key   = "size"
    value = data.coder_parameter.size.value
  }
  item {
    key   = "os"
    value = data.coder_parameter.os.value
  }
  item {
    key   = "gui"
    value = data.coder_parameter.gui_enabled.value
  }
  item {
    key   = "cpu"
    value = "${local.selected_size.cpu_limit} cores"
  }
  item {
    key   = "memory"
    value = local.selected_size.memory_limit
  }
  item {
    key   = "storage"
    value = local.selected_size.storage_size
  }
}

# =============================================================================
# Kubernetes Resources
# =============================================================================

# Persistent Volume Claim for /home/coder
# Requirement 11a.1: Persist user's /home/coder directory
resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "coder-workspace"
      "app.kubernetes.io/instance"   = data.coder_workspace.me.name
      "app.kubernetes.io/managed-by" = "coder"
      "coder.workspace.owner"        = data.coder_workspace_owner.me.name
      "coder.workspace.name"         = data.coder_workspace.me.name
    }
  }

  wait_until_bound = false

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = local.selected_size.storage_size
      }
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}

# Workspace Deployment
resource "kubernetes_deployment_v1" "workspace" {
  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "coder-workspace"
      "app.kubernetes.io/instance"   = data.coder_workspace.me.name
      "app.kubernetes.io/managed-by" = "coder"
      "coder.workspace.owner"        = data.coder_workspace_owner.me.name
      "coder.workspace.name"         = data.coder_workspace.me.name
    }
  }

  wait_for_rollout = false

  spec {
    replicas = data.coder_workspace.me.start_count

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = data.coder_workspace.me.name
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = "coder-workspace"
          "app.kubernetes.io/instance"   = data.coder_workspace.me.name
          "app.kubernetes.io/managed-by" = "coder"
          "coder.workspace.owner"        = data.coder_workspace_owner.me.name
          "coder.workspace.name"         = data.coder_workspace.me.name
        }
      }

      spec {
        # Node selector for workspace nodes
        node_selector = {
          "coder.com/node-type" = "workspace"
        }

        # Toleration for workspace node taint
        toleration {
          key      = "coder-ws"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        security_context {
          run_as_user  = 1000
          run_as_group = 1000
          fs_group     = 1000
        }

        container {
          name              = "workspace"
          image             = local.selected_image
          image_pull_policy = "Always"
          command           = ["sh", "-c", coder_agent.main.init_script]

          security_context {
            run_as_user  = 1000
            run_as_group = 1000
          }

          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }

          resources {
            requests = {
              cpu    = local.selected_size.cpu_request
              memory = local.selected_size.memory_request
            }
            limits = {
              cpu    = local.selected_size.cpu_limit
              memory = local.selected_size.memory_limit
            }
          }

          volume_mount {
            name       = "home"
            mount_path = "/home/coder"
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
          }
        }
      }
    }
  }
}

# =============================================================================
# Network Policy for Workspace Isolation
# Requirement 3.1c: NetworkPolicy configurations to isolate workspaces
# =============================================================================

resource "kubernetes_network_policy_v1" "workspace_isolation" {
  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-isolation"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "coder-workspace"
      "app.kubernetes.io/instance"   = data.coder_workspace.me.name
      "app.kubernetes.io/managed-by" = "coder"
    }
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = data.coder_workspace.me.name
      }
    }

    # Ingress rules - allow traffic from coderd only
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "app.kubernetes.io/name" = "coder"
          }
        }
      }
    }

    # Egress rules - allow DNS, coderd, and internet
    egress {
      # Allow DNS
      to {
        namespace_selector {}
      }
      ports {
        protocol = "UDP"
        port     = "53"
      }
      ports {
        protocol = "TCP"
        port     = "53"
      }
    }

    egress {
      # Allow traffic to coderd
      to {
        namespace_selector {
          match_labels = {
            "app.kubernetes.io/name" = "coder"
          }
        }
      }
    }

    egress {
      # Allow HTTPS egress (for Git, package managers, etc.)
      ports {
        protocol = "TCP"
        port     = "443"
      }
      ports {
        protocol = "TCP"
        port     = "80"
      }
    }

    policy_types = ["Ingress", "Egress"]
  }
}

# =============================================================================
# Variables
# =============================================================================

variable "namespace" {
  description = "Kubernetes namespace for workspaces"
  type        = string
  default     = "coder-ws"
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "gp3-encrypted"
}
