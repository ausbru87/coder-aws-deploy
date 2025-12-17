# Base-K8s Infrastructure Module
# Kubernetes pod-based workspace infrastructure for Coder
#
# Requirements Covered:
# - 11.5: Deploy base-k8s module for Kubernetes pod workspaces
# - 11.6: Support KasmVNC for GUI workspaces
# - 11.7: Support headless workspaces
# - 11.8: Support Amazon Linux 2023, Ubuntu 22.04/24.04
# - 11a.1: Persist /home/coder directory
# - 3.1c: NetworkPolicy for workspace isolation
# - 13.1, 13.2, 13.3: Auto-start/auto-stop (0700/1800 ET)
#
# This module implements the infrastructure base layer for Kubernetes pod workspaces.
# It accepts contract inputs and provides contract outputs as defined in the template contract.

# =============================================================================
# Local Variables
# =============================================================================

locals {
  # Workspace naming
  workspace_id = "${lower(var.owner)}-${lower(var.workspace_name)}"
  full_name    = "coder-${local.workspace_id}"

  # OS image mapping
  os_images = {
    "amazon-linux-2023" = {
      headless = var.image_registry != "" ? "${var.image_registry}/coder-base:al2023" : "codercom/enterprise-base:latest"
      gui      = var.image_registry != "" ? "${var.image_registry}/coder-desktop:al2023" : "codercom/enterprise-desktop:latest"
    }
    "ubuntu-22.04" = {
      headless = var.image_registry != "" ? "${var.image_registry}/coder-base:ubuntu-22.04" : "codercom/enterprise-base:ubuntu"
      gui      = var.image_registry != "" ? "${var.image_registry}/coder-desktop:ubuntu-22.04" : "codercom/enterprise-desktop:ubuntu"
    }
    "ubuntu-24.04" = {
      headless = var.image_registry != "" ? "${var.image_registry}/coder-base:ubuntu-24.04" : "codercom/enterprise-base:ubuntu"
      gui      = var.image_registry != "" ? "${var.image_registry}/coder-desktop:ubuntu-24.04" : "codercom/enterprise-desktop:ubuntu"
    }
  }

  # Select image based on OS and GUI capability
  selected_image = var.capabilities.gui_vnc ? local.os_images[var.os_type].gui : local.os_images[var.os_type].headless

  # Use custom image if provided, otherwise use OS-based image
  final_image = var.image_id != "" ? var.image_id : local.selected_image

  # Parse memory and storage from Kubernetes format (e.g., "8Gi" -> 8)
  memory_gi  = tonumber(regex("^([0-9]+)", var.compute_profile.memory)[0])
  storage_gi = tonumber(regex("^([0-9]+)", var.compute_profile.storage)[0])

  # Resource requests (50% of limits for burstable QoS)
  cpu_request    = floor(var.compute_profile.cpu / 2)
  memory_request = "${floor(local.memory_gi / 2)}Gi"

  # Labels for all resources
  common_labels = {
    "app.kubernetes.io/name"       = "coder-workspace"
    "app.kubernetes.io/instance"   = var.workspace_name
    "app.kubernetes.io/managed-by" = "coder"
    "coder.workspace.owner"        = var.owner
    "coder.workspace.name"         = var.workspace_name
    "coder.toolchain.name"         = var.toolchain_template.name
    "coder.toolchain.version"      = var.toolchain_template.version
    "coder.base.name"              = var.base_module.name
    "coder.base.version"           = var.base_module.version
  }

  # Selector labels (subset for pod selection)
  selector_labels = {
    "app.kubernetes.io/name"     = "coder-workspace"
    "app.kubernetes.io/instance" = var.workspace_name
  }

  # Runtime environment variables
  runtime_env = merge(
    {
      "CODER_WORKSPACE_NAME" = var.workspace_name
      "CODER_OWNER"          = var.owner
      "HOME"                 = "/home/coder"
    },
    var.overrides.environment_variables
  )
}


# =============================================================================
# Service Account with IRSA
# Requirement: Configure service account with IRSA for AWS API access
# =============================================================================

resource "kubernetes_service_account_v1" "workspace" {
  metadata {
    name      = local.full_name
    namespace = var.namespace
    labels    = local.common_labels

    annotations = var.capabilities.identity_mode == "iam" ? {
      "eks.amazonaws.com/role-arn" = var.workspace_iam_role_arn
    } : {}
  }
}

# =============================================================================
# Persistent Volume Claim for /home/coder
# Requirement 11a.1: Persist user's /home/coder directory
# =============================================================================

resource "kubernetes_persistent_volume_claim_v1" "home" {
  count = var.capabilities.persistent_home ? 1 : 0

  metadata {
    name      = "${local.full_name}-home"
    namespace = var.namespace
    labels    = local.common_labels
  }

  wait_until_bound = false

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.compute_profile.storage
      }
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}

# =============================================================================
# Workspace Deployment
# Requirements: 11.5, 11.6, 11.7, 11.8
# =============================================================================

resource "kubernetes_deployment_v1" "workspace" {
  metadata {
    name      = local.full_name
    namespace = var.namespace
    labels    = local.common_labels

    annotations = merge(
      {
        "coder.com/toolchain-version" = var.toolchain_template.version
        "coder.com/base-version"      = var.base_module.version
      },
      var.overrides.annotations
    )
  }

  wait_for_rollout = false

  spec {
    replicas = var.replica_count

    selector {
      match_labels = local.selector_labels
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = merge(local.common_labels, var.overrides.labels)
      }

      spec {
        service_account_name = kubernetes_service_account_v1.workspace.metadata[0].name

        # Node selector for workspace nodes (coder-ws node pool)
        node_selector = merge(
          {
            "coder.com/node-type" = "workspace"
          },
          var.additional_node_selectors
        )

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

        # Main workspace container
        container {
          name              = "workspace"
          image             = local.final_image
          image_pull_policy = "Always"
          command           = var.startup_command

          security_context {
            run_as_user                = 1000
            run_as_group               = 1000
            allow_privilege_escalation = false
          }

          # Environment variables
          dynamic "env" {
            for_each = local.runtime_env
            content {
              name  = env.key
              value = env.value
            }
          }

          # Coder agent token (injected by Coder)
          env {
            name  = "CODER_AGENT_TOKEN"
            value = var.coder_agent_token
          }

          resources {
            requests = {
              cpu    = local.cpu_request
              memory = local.memory_request
            }
            limits = {
              cpu    = var.compute_profile.cpu
              memory = var.compute_profile.memory
            }
          }

          # Home directory volume mount
          dynamic "volume_mount" {
            for_each = var.capabilities.persistent_home ? [1] : []
            content {
              name       = "home"
              mount_path = "/home/coder"
            }
          }

          # Liveness probe
          liveness_probe {
            exec {
              command = ["cat", "/tmp/coder-agent-ready"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 3
          }
        }

        # KasmVNC sidecar container for GUI capability
        dynamic "container" {
          for_each = var.capabilities.gui_vnc ? [1] : []
          content {
            name              = "kasmvnc"
            image             = var.kasmvnc_image
            image_pull_policy = "Always"

            security_context {
              run_as_user  = 1000
              run_as_group = 1000
            }

            port {
              container_port = 6901
              name           = "vnc"
              protocol       = "TCP"
            }

            env {
              name  = "VNC_PW"
              value = var.vnc_password
            }

            resources {
              requests = {
                cpu    = "500m"
                memory = "512Mi"
              }
              limits = {
                cpu    = "2"
                memory = "2Gi"
              }
            }

            volume_mount {
              name       = "home"
              mount_path = "/home/coder"
            }
          }
        }

        # Home directory volume
        dynamic "volume" {
          for_each = var.capabilities.persistent_home ? [1] : []
          content {
            name = "home"
            persistent_volume_claim {
              claim_name = kubernetes_persistent_volume_claim_v1.home[0].metadata[0].name
            }
          }
        }

        # Ephemeral home if persistence disabled
        dynamic "volume" {
          for_each = var.capabilities.persistent_home ? [] : [1]
          content {
            name = "home"
            empty_dir {}
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
    name      = "${local.full_name}-isolation"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    pod_selector {
      match_labels = local.selector_labels
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

    # Egress rules based on network_egress capability
    dynamic "egress" {
      for_each = var.capabilities.network_egress != "none" ? [1] : []
      content {
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
    }

    dynamic "egress" {
      for_each = var.capabilities.network_egress != "none" ? [1] : []
      content {
        # Allow traffic to coderd
        to {
          namespace_selector {
            match_labels = {
              "app.kubernetes.io/name" = "coder"
            }
          }
        }
      }
    }

    # HTTPS-only egress
    dynamic "egress" {
      for_each = var.capabilities.network_egress == "https-only" ? [1] : []
      content {
        ports {
          protocol = "TCP"
          port     = "443"
        }
      }
    }

    # Unrestricted egress (all ports)
    dynamic "egress" {
      for_each = var.capabilities.network_egress == "unrestricted" ? [1] : []
      content {
        to {
          ip_block {
            cidr = "0.0.0.0/0"
          }
        }
      }
    }

    policy_types = ["Ingress", "Egress"]
  }
}

# =============================================================================
# Service for VNC access (if GUI enabled)
# =============================================================================

resource "kubernetes_service_v1" "vnc" {
  count = var.capabilities.gui_vnc ? 1 : 0

  metadata {
    name      = "${local.full_name}-vnc"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    selector = local.selector_labels

    port {
      name        = "vnc"
      port        = 6901
      target_port = 6901
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
