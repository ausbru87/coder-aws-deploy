# =============================================================================
# Computed Values from Feature Flags
# =============================================================================
# This file contains computed values derived from deployment_features flags.
# These locals allow modules to adapt their behavior based on the selected
# deployment pattern (SR-HA or SR-Simple)
# =============================================================================

locals {
  # ============================================================================
  # High Availability Configuration
  # ============================================================================
  # Derive HA settings from feature flag
  availability_zone_count = var.deployment_features.high_availability ? 3 : 1
  coderd_replicas         = var.deployment_features.high_availability ? 2 : 1
  enable_spot_instances   = var.deployment_features.high_availability
  nat_gateway_count       = var.deployment_features.high_availability ? 3 : 1

  # ============================================================================
  # Time-Based Scaling Configuration
  # ============================================================================
  # Enable autoscaling schedules only if time_based_scaling is true
  enable_autoscaling_schedules = var.deployment_features.time_based_scaling

  # ============================================================================
  # VPC Configuration
  # ============================================================================
  # Use variable for VPC endpoints (can be overridden per deployment)
  vpc_endpoints_enabled = var.enable_vpc_endpoints

  # ============================================================================
  # Logging Configuration
  # ============================================================================
  # Use variable for log retention (90 days default for SR-HA)
  computed_log_retention_days = var.log_retention_days

  # ============================================================================
  # Instance Configuration
  # ============================================================================
  # Use spot instances based on HA flag (SR-HA uses spot, SR-Simple uses on-demand)
  use_spot_instances = var.deployment_features.high_availability ? var.ws_use_spot_instances : false

  # ============================================================================
  # Deployment Pattern Identification
  # ============================================================================
  deployment_pattern = (
    var.deployment_features.high_availability && var.deployment_features.time_based_scaling ? "sr-ha" :
    var.deployment_features.high_availability ? "sr-ha-static" :
    "sr-simple"
  )

  # ============================================================================
  # Common Tags
  # ============================================================================
  common_tags = {
    Project           = var.project_name
    Environment       = var.environment
    Owner             = var.owner
    ManagedBy         = "terraform"
    DeploymentPattern = local.deployment_pattern
    HighAvailability  = tostring(var.deployment_features.high_availability)
    TimeBasedScaling  = tostring(var.deployment_features.time_based_scaling)
  }
}
