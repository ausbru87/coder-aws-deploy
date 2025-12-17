# Template Deployment Module - Main
# Requirements: 16.3, 12b.3
#
# This module deploys composed templates to Coder using the coderd provider.

terraform {
  required_version = ">= 1.0"

  required_providers {
    coderd = {
      source  = "coder/coderd"
      version = ">= 0.0.12"
    }
  }
}

# =============================================================================
# ACL CONFIGURATION
# =============================================================================

locals {
  # Define ACL configurations per template type
  # Requirement 12b.3: Configure template access permissions
  # Requirement 14.17: Restrict access to large resource templates

  acl_configs = {
    # pod-swdev: Standard development template - broad access
    "pod-swdev" = {
      groups = [
        {
          id   = var.developers_group_id
          role = "use"
        },
        {
          id   = var.platform_admins_group_id
          role = "use"
        },
        {
          id   = var.template_owners_group_id
          role = "admin"
        }
      ]
      users = []
    }

    # ec2-windev-gui: Windows development - developers and template owners
    "ec2-windev-gui" = {
      groups = [
        {
          id   = var.developers_group_id
          role = "use"
        },
        {
          id   = var.template_owners_group_id
          role = "admin"
        }
      ]
      users = []
    }

    # ec2-datasci: Data science (CPU) - restricted access (Requirement 14.17)
    "ec2-datasci" = {
      groups = [
        {
          id   = var.template_owners_group_id
          role = "admin"
        }
        # Data science group access should be added when the group is created
      ]
      users = []
    }

    # ec2-datasci-gpu: Data science (GPU) - restricted access (Requirement 14.17)
    "ec2-datasci-gpu" = {
      groups = [
        {
          id   = var.template_owners_group_id
          role = "admin"
        }
        # Data science group access should be added when the group is created
      ]
      users = []
    }
  }
}

# =============================================================================
# TEMPLATE DIRECTORY MAPPING
# =============================================================================

locals {
  # Map pairing names to template directories
  template_directories = {
    "pod-swdev"       = "${var.template_directory_base}/pod-swdev"
    "ec2-windev-gui"  = "${var.template_directory_base}/ec2-windev-gui"
    "ec2-datasci"     = "${var.template_directory_base}/ec2-datasci"
    "ec2-datasci-gpu" = "${var.template_directory_base}/ec2-datasci" # Uses same template with GPU config
  }

  # Default Terraform variables for each template
  default_tf_vars = {
    "pod-swdev" = [
      {
        name  = "namespace"
        value = "coder-ws"
      },
      {
        name  = "storage_class"
        value = "gp3-encrypted"
      }
    ]
    "ec2-windev-gui" = [
      {
        name  = "instance_type"
        value = "m5.xlarge"
      }
    ]
    "ec2-datasci" = [
      {
        name  = "instance_type"
        value = "m5.2xlarge"
      },
      {
        name  = "enable_gpu"
        value = "false"
      }
    ]
    "ec2-datasci-gpu" = [
      {
        name  = "instance_type"
        value = "g4dn.xlarge"
      },
      {
        name  = "enable_gpu"
        value = "true"
      }
    ]
  }
}

# =============================================================================
# TEMPLATE RESOURCES
# Requirement 16.3: Use coderd_template resource for declarative template management
# =============================================================================

# Note: Due to coderd provider limitations with unknown values during validation,
# we define templates individually rather than using for_each with complex objects.
# This ensures tf_vars are fully known at plan time.

# Pod Software Development Template
resource "coderd_template" "pod_swdev" {
  count = var.enable_deployment && contains(keys(var.pairing_configs), "pod-swdev") ? 1 : 0

  organization_id = var.organization_id
  name            = "pod-swdev"
  display_name    = var.pairing_configs["pod-swdev"].display_name
  description     = var.pairing_configs["pod-swdev"].description
  icon            = var.pairing_configs["pod-swdev"].icon

  versions = [
    {
      directory = "${var.template_directory_base}/pod-swdev"
      active    = true
      name      = var.template_version
      tf_vars = [
        { name = "namespace", value = var.pairing_configs["pod-swdev"].namespace },
        { name = "storage_class", value = var.pairing_configs["pod-swdev"].storage_class }
      ]
    }
  ]

  default_ttl_ms                 = var.pairing_configs["pod-swdev"].default_ttl_ms
  activity_bump_ms               = var.pairing_configs["pod-swdev"].activity_bump_ms
  allow_user_auto_start          = true
  allow_user_auto_stop           = true
  failure_ttl_ms                 = var.pairing_configs["pod-swdev"].failure_ttl_ms
  time_til_dormant_ms            = var.pairing_configs["pod-swdev"].time_til_dormant_ms
  time_til_dormant_autodelete_ms = var.pairing_configs["pod-swdev"].time_til_dormant_autodelete_ms
  deprecation_message            = lookup(var.template_deprecation_messages, "pod-swdev", "")

  acl = local.acl_configs["pod-swdev"]
}

# EC2 Windows Development Template
resource "coderd_template" "ec2_windev_gui" {
  count = var.enable_deployment && contains(keys(var.pairing_configs), "ec2-windev-gui") ? 1 : 0

  organization_id = var.organization_id
  name            = "ec2-windev-gui"
  display_name    = var.pairing_configs["ec2-windev-gui"].display_name
  description     = var.pairing_configs["ec2-windev-gui"].description
  icon            = var.pairing_configs["ec2-windev-gui"].icon

  versions = [
    {
      directory = "${var.template_directory_base}/ec2-windev-gui"
      active    = true
      name      = var.template_version
      tf_vars = [
        { name = "instance_type", value = "m5.xlarge" }
      ]
    }
  ]

  default_ttl_ms                 = var.pairing_configs["ec2-windev-gui"].default_ttl_ms
  activity_bump_ms               = var.pairing_configs["ec2-windev-gui"].activity_bump_ms
  allow_user_auto_start          = true
  allow_user_auto_stop           = true
  failure_ttl_ms                 = var.pairing_configs["ec2-windev-gui"].failure_ttl_ms
  time_til_dormant_ms            = var.pairing_configs["ec2-windev-gui"].time_til_dormant_ms
  time_til_dormant_autodelete_ms = var.pairing_configs["ec2-windev-gui"].time_til_dormant_autodelete_ms
  deprecation_message            = lookup(var.template_deprecation_messages, "ec2-windev-gui", "")

  acl = local.acl_configs["ec2-windev-gui"]
}

# EC2 Data Science Template (CPU)
resource "coderd_template" "ec2_datasci" {
  count = var.enable_deployment && contains(keys(var.pairing_configs), "ec2-datasci") ? 1 : 0

  organization_id = var.organization_id
  name            = "ec2-datasci"
  display_name    = var.pairing_configs["ec2-datasci"].display_name
  description     = var.pairing_configs["ec2-datasci"].description
  icon            = var.pairing_configs["ec2-datasci"].icon

  versions = [
    {
      directory = "${var.template_directory_base}/ec2-datasci"
      active    = true
      name      = var.template_version
      tf_vars = [
        { name = "instance_type", value = "m5.2xlarge" },
        { name = "enable_gpu", value = "false" }
      ]
    }
  ]

  default_ttl_ms                 = var.pairing_configs["ec2-datasci"].default_ttl_ms
  activity_bump_ms               = var.pairing_configs["ec2-datasci"].activity_bump_ms
  allow_user_auto_start          = true
  allow_user_auto_stop           = true
  failure_ttl_ms                 = var.pairing_configs["ec2-datasci"].failure_ttl_ms
  time_til_dormant_ms            = var.pairing_configs["ec2-datasci"].time_til_dormant_ms
  time_til_dormant_autodelete_ms = var.pairing_configs["ec2-datasci"].time_til_dormant_autodelete_ms
  deprecation_message            = lookup(var.template_deprecation_messages, "ec2-datasci", "")

  acl = local.acl_configs["ec2-datasci"]
}

# EC2 Data Science Template (GPU)
resource "coderd_template" "ec2_datasci_gpu" {
  count = var.enable_deployment && contains(keys(var.pairing_configs), "ec2-datasci-gpu") ? 1 : 0

  organization_id = var.organization_id
  name            = "ec2-datasci-gpu"
  display_name    = var.pairing_configs["ec2-datasci-gpu"].display_name
  description     = var.pairing_configs["ec2-datasci-gpu"].description
  icon            = var.pairing_configs["ec2-datasci-gpu"].icon

  versions = [
    {
      directory = "${var.template_directory_base}/ec2-datasci"
      active    = true
      name      = var.template_version
      tf_vars = [
        { name = "instance_type", value = "g4dn.xlarge" },
        { name = "enable_gpu", value = "true" }
      ]
    }
  ]

  default_ttl_ms                 = var.pairing_configs["ec2-datasci-gpu"].default_ttl_ms
  activity_bump_ms               = var.pairing_configs["ec2-datasci-gpu"].activity_bump_ms
  allow_user_auto_start          = true
  allow_user_auto_stop           = true
  failure_ttl_ms                 = var.pairing_configs["ec2-datasci-gpu"].failure_ttl_ms
  time_til_dormant_ms            = var.pairing_configs["ec2-datasci-gpu"].time_til_dormant_ms
  time_til_dormant_autodelete_ms = var.pairing_configs["ec2-datasci-gpu"].time_til_dormant_autodelete_ms
  deprecation_message            = lookup(var.template_deprecation_messages, "ec2-datasci-gpu", "")

  acl = local.acl_configs["ec2-datasci-gpu"]
}

# =============================================================================
# PROVENANCE TRACKING
# =============================================================================

locals {
  # Generate provenance records for all deployed templates
  deployment_provenance = merge(
    length(coderd_template.pod_swdev) > 0 ? {
      "pod-swdev" = {
        template_id = coderd_template.pod_swdev[0].id
        name        = "pod-swdev"
        version     = var.template_version
        toolchain = {
          name    = var.pairing_configs["pod-swdev"].toolchain_name
          version = var.pairing_configs["pod-swdev"].toolchain_version
        }
        base = {
          name    = var.pairing_configs["pod-swdev"].base_name
          version = var.pairing_configs["pod-swdev"].base_version
        }
        deployed_at = timestamp()
        deployed_by = "terraform"
      }
    } : {},
    length(coderd_template.ec2_windev_gui) > 0 ? {
      "ec2-windev-gui" = {
        template_id = coderd_template.ec2_windev_gui[0].id
        name        = "ec2-windev-gui"
        version     = var.template_version
        toolchain = {
          name    = var.pairing_configs["ec2-windev-gui"].toolchain_name
          version = var.pairing_configs["ec2-windev-gui"].toolchain_version
        }
        base = {
          name    = var.pairing_configs["ec2-windev-gui"].base_name
          version = var.pairing_configs["ec2-windev-gui"].base_version
        }
        deployed_at = timestamp()
        deployed_by = "terraform"
      }
    } : {},
    length(coderd_template.ec2_datasci) > 0 ? {
      "ec2-datasci" = {
        template_id = coderd_template.ec2_datasci[0].id
        name        = "ec2-datasci"
        version     = var.template_version
        toolchain = {
          name    = var.pairing_configs["ec2-datasci"].toolchain_name
          version = var.pairing_configs["ec2-datasci"].toolchain_version
        }
        base = {
          name    = var.pairing_configs["ec2-datasci"].base_name
          version = var.pairing_configs["ec2-datasci"].base_version
        }
        deployed_at = timestamp()
        deployed_by = "terraform"
      }
    } : {},
    length(coderd_template.ec2_datasci_gpu) > 0 ? {
      "ec2-datasci-gpu" = {
        template_id = coderd_template.ec2_datasci_gpu[0].id
        name        = "ec2-datasci-gpu"
        version     = var.template_version
        toolchain = {
          name    = var.pairing_configs["ec2-datasci-gpu"].toolchain_name
          version = var.pairing_configs["ec2-datasci-gpu"].toolchain_version
        }
        base = {
          name    = var.pairing_configs["ec2-datasci-gpu"].base_name
          version = var.pairing_configs["ec2-datasci-gpu"].base_version
        }
        deployed_at = timestamp()
        deployed_by = "terraform"
      }
    } : {}
  )
}
