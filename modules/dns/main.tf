# ==============================================================================
# modules/dns/main.tf
#
# Route 53 public hosted zone for the custom base domain (e.g. gilead.com)
#
# NEW AWS ACCOUNT FLOW (create_hosted_zone = true):
#   1. Terraform creates the Route 53 public hosted zone.
#   2. After apply: terraform output route53_ns_records
#   3. Add the 4 NS records at your domain registrar.
#   4. Wait for DNS propagation (5–48 hours).
#   ROSA then auto-creates:
#     A  api.<cluster>.<domain>       → internal API NLB
#     A  api-int.<cluster>.<domain>   → internal API NLB
#     A  *.apps.<cluster>.<domain>    → internal Ingress NLB
#
# EXISTING ZONE (create_hosted_zone = false):
#   Set hosted_zone_id in your tfvars to the existing Route 53 Zone ID.
#   (AWS Console → Route 53 → Hosted Zones → <domain> → Hosted zone ID)
# ==============================================================================

# Create the hosted zone (new AWS account — zone doesn't exist yet)
resource "aws_route53_zone" "base_domain" {
  count   = var.create_hosted_zone ? 1 : 0
  name    = var.base_domain
  comment = "Managed by Terraform — ROSA cluster ${var.cluster_name}"
}

# Look up an existing hosted zone (when create_hosted_zone = false)
data "aws_route53_zone" "existing" {
  count        = var.create_hosted_zone ? 0 : 1
  zone_id      = var.hosted_zone_id
  private_zone = false
}

locals {
  # Unified zone ID regardless of whether we created it or looked it up
  zone_id    = var.create_hosted_zone ? aws_route53_zone.base_domain[0].zone_id : data.aws_route53_zone.existing[0].zone_id

  # NS records to add at your domain registrar (only relevant when zone is newly created)
  ns_records = var.create_hosted_zone ? aws_route53_zone.base_domain[0].name_servers : []
}
