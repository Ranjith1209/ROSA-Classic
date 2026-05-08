output "zone_id" {
  description = "Route53 hosted zone ID -- passed to ROSA cluster as aws_route53_hosted_zone_id"
  value       = local.zone_id
}

output "ns_records" {
  description = "NS records to add at your domain registrar (only when create_hosted_zone = true)"
  value       = local.ns_records
}
