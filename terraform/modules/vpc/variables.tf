# VPC Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "max_workspaces" {
  description = "Maximum number of concurrent workspaces for CIDR sizing"
  type        = number
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Workspace Egress Configuration
# Requirements: 3.1d, 3.1e

variable "workspace_allow_internet_egress" {
  description = "Allow workspace nodes to access the internet (filtered to HTTPS, HTTP, SSH)"
  type        = bool
  default     = true
}

variable "onprem_cidr_blocks" {
  description = "List of on-premises CIDR blocks that workspaces can access"
  type        = list(string)
  default     = []
}

variable "additional_aws_cidr_blocks" {
  description = "List of additional AWS VPC CIDR blocks that workspaces can access (e.g., peered VPCs)"
  type        = list(string)
  default     = []
}

variable "workspace_allowed_egress_ports" {
  description = "Additional ports to allow for workspace egress (beyond HTTPS, HTTP, SSH, DNS)"
  type        = list(number)
  default     = []
}
