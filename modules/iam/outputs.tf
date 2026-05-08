output "installer_role_arn" {
  description = "Installer IAM Role ARN — passed to ROSA cluster STS block"
  value       = aws_iam_role.installer.arn
}

output "support_role_arn" {
  description = "Support IAM Role ARN — passed to ROSA cluster STS block"
  value       = aws_iam_role.support.arn
}

output "control_plane_role_arn" {
  description = "ControlPlane IAM Role ARN — passed to ROSA cluster STS instance_iam_roles"
  value       = aws_iam_role.control_plane.arn
}

output "worker_role_arn" {
  description = "Worker IAM Role ARN — passed to ROSA cluster STS instance_iam_roles"
  value       = aws_iam_role.worker.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL — passed to ROSA cluster STS oidc_endpoint_url"
  value       = aws_iam_openid_connect_provider.rosa.url
}
