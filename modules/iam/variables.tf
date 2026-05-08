variable "aws_region" {
  type        = string
  description = "AWS region — used in the OIDC provider URL."
}

variable "cluster_name" {
  type        = string
  description = "ROSA cluster name — used in IAM resource names and trust conditions."
}

variable "redhat_account_id" {
  type        = string
  description = "Red Hat's AWS account ID that the Installer and Support roles trust. Unlikely to change."
  default     = "710019948333"
}

variable "oidc_thumbprint" {
  type        = string
  description = "TLS certificate thumbprint for Red Hat's hosted OIDC issuer (rh-oidc.s3.amazonaws.com). Rotate if Red Hat renews the certificate."
  default     = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all IAM resources."
  default     = {}
}
