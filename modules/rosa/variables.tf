variable "cluster_name" {
  type        = string
  description = "ROSA cluster name."
}

variable "create_admin_user" {
  type        = bool
  description = "Create a default cluster admin user with generated password."
  default     = true
}

variable "private" {
  type        = bool
  description = "Make cluster API and Ingress endpoints private (internal NLBs only)."
  default     = true
}

variable "aws_private_link" {
  type        = bool
  description = "Enable AWS PrivateLink for Red Hat SRE access."
  default     = true
}

variable "multi_az" {
  type        = bool
  description = "Deploy control plane across multiple AZs."
  default     = false
}

variable "wait_for_create_complete" {
  type        = bool
  description = "Block terraform apply until the cluster reaches Ready state (~40 min)."
  default     = true
}

variable "managed_policies" {
  type        = bool
  description = "Use Red Hat managed STS policies instead of inline policies."
  default     = true
}

variable "machine_pool_labels" {
  type        = map(string)
  description = "Kubernetes labels applied to all nodes in the worker machine pool."
  default = {
    "node-role.kubernetes.io/worker" = ""
    "mas-workload"                   = "true"
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region."
}

variable "openshift_version" {
  type        = string
  description = "OpenShift version. Check: rosa list versions."
}

variable "availability_zones" {
  type        = list(string)
  description = "2 AZ names for worker distribution."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs from vpc module — passed to ROSA."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR used as machine_cidr for ROSA."
}

variable "base_domain" {
  type        = string
  description = "Custom DNS domain (e.g. gilead.com). ROSA creates A records inside Route53 zone."
}

variable "service_cidr" {
  type        = string
  description = "OpenShift service network CIDR. Must not overlap VPC, pod_cidr, or host OS ranges."
}

variable "pod_cidr" {
  type        = string
  description = "OpenShift pod network CIDR. Must not overlap VPC, service_cidr, or host OS ranges."
}

variable "host_prefix" {
  type        = number
  description = "Subnet prefix length assigned to each node for pod IPs (e.g. 23 = /23 per node)."
}

variable "machine_pool_name" {
  type        = string
  description = "Name of the additional machine pool for worker nodes."
}

variable "worker_instance_type" {
  type        = string
  description = "EC2 instance type for worker nodes."
}

variable "worker_node_count" {
  type        = number
  description = "Number of worker nodes (masters are always 3, managed by Red Hat)."
}

variable "worker_disk_size_gb" {
  type        = number
  description = "Worker root EBS disk size in GB. Minimum 128."
}

variable "installer_role_arn" {
  type        = string
  description = "Installer IAM Role ARN from iam module."
}

variable "support_role_arn" {
  type        = string
  description = "Support IAM Role ARN from iam module."
}

variable "control_plane_role_arn" {
  type        = string
  description = "ControlPlane IAM Role ARN from iam module."
}

variable "worker_role_arn" {
  type        = string
  description = "Worker IAM Role ARN from iam module."
}

variable "oidc_endpoint_url" {
  type        = string
  description = "OIDC provider URL from iam module."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to cluster resources."
  default     = {}
}
