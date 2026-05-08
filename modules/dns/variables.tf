variable "cluster_name" {
  type        = string
  description = "ROSA cluster name -- used in zone comment."
}

variable "base_domain" {
  type        = string
  description = "Custom DNS domain. e.g. gilead.com"
}

variable "create_hosted_zone" {
  type        = bool
  description = "true = create new Route53 zone. false = look up existing zone (set hosted_zone_id)."
  default     = true
}

variable "hosted_zone_id" {
  type        = string
  description = "Existing Route53 zone ID. Used only when create_hosted_zone = false."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the hosted zone."
  default     = {}
}
