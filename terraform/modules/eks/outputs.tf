# EKS Module Outputs

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster API"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "cluster_security_group_id" {
  description = "Security group ID for the cluster"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID for nodes"
  value       = aws_security_group.node.id
}

output "coder_server_role_arn" {
  description = "ARN of the Coder server IAM role"
  value       = aws_iam_role.coder_server.arn
}

output "coder_prov_role_arn" {
  description = "ARN of the Coder provisioner IAM role"
  value       = aws_iam_role.coder_provisioner.arn
}

output "aws_lb_controller_role_arn" {
  description = "ARN of the AWS LB Controller IAM role"
  value       = aws_iam_role.aws_lb_controller.arn
}

output "ebs_csi_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi.arn
}

output "control_node_group_name" {
  description = "Name of the control node group"
  value       = aws_eks_node_group.control.node_group_name
}

output "provisioner_node_group_name" {
  description = "Name of the provisioner node group"
  value       = aws_eks_node_group.provisioner.node_group_name
}

output "workspace_node_group_name" {
  description = "Name of the workspace node group"
  value       = aws_eks_node_group.workspace.node_group_name
}

output "workspace_launch_template_id" {
  description = "ID of the workspace node launch template"
  value       = aws_launch_template.workspace.id
}

output "workspace_launch_template_version" {
  description = "Latest version of the workspace node launch template"
  value       = aws_launch_template.workspace.latest_version
}

# =============================================================================
# Kubernetes Controller Outputs
# =============================================================================

output "aws_lb_controller_status" {
  description = "Status of AWS Load Balancer Controller Helm release"
  value       = helm_release.aws_load_balancer_controller.status
}

output "ebs_csi_addon_version" {
  description = "Version of EBS CSI Driver addon"
  value       = aws_eks_addon.ebs_csi.addon_version
}

output "default_storage_class" {
  description = "Name of the default storage class"
  value       = kubernetes_storage_class_v1.gp3_encrypted.metadata[0].name
}
