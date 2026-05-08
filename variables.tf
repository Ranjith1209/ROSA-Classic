# ==============================================================================
# variables.tf -- Root Module Variable Declarations
#
# NO defaults are set here. Every value must be supplied via a tfvars file:
#   terraform plan  -var-file=dev.tfvars
#   terraform apply -var-file=dev.tfvars
#
# Sensitive values (RHCS_TOKEN) come from GitHub Actions secrets — never
# commit them to the repository.
# ==============================================================================

# ── Core ──────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy the ROSA cluster and supporting resources."
  type        = string
}

variable "cluster_name" {
  description = "Name of the ROSA Classic cluster. Used in resource names, tags, and DNS."
  type        = string
}

variable "openshift_version" {
  description = "OpenShift version for ROSA cluster."
  type        = string
}

variable "environment" {
  description = "Deployment environment. Applied as the Environment default tag on all resources."
  type        = string

  validation {
    condition     = contains(["Non-Prod", "Val", "Prod"], var.environment)
    error_message = "environment must be one of: Non-Prod, Val, Prod."
  }
}

variable "project_name" {
  description = "Project name applied as the Project default tag on all resources."
  type        = string
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be at least /16 for ROSA."
  type        = string
}

variable "availability_zones" {
  description = "Exactly 2 availability zones. Workers spread across both; single control-plane AZ."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones are required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the 2 private subnets -- one per AZ. ROSA workers/masters run here."
  type        = list(string)
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public subnet. Hosts the NAT Gateway only."
  type        = string
}

variable "master_subnet_name" {
  description = "AWS Name tag for the master/private subnet in AZ-a."
  type        = string
}

variable "worker_subnet_name" {
  description = "AWS Name tag for the worker/private subnet in AZ-b."
  type        = string
}

variable "public_subnet_name" {
  description = "AWS Name tag for the public subnet (NAT Gateway)."
  type        = string
}

# ── OpenShift Networking ──────────────────────────────────────────────────────

variable "service_cidr" {
  description = "OpenShift service network CIDR. Must not overlap VPC, pod, or host OS ranges."
  type        = string
}

variable "pod_cidr" {
  description = "OpenShift pod network CIDR. Must not overlap VPC, service, or host OS ranges."
  type        = string
}

variable "host_prefix" {
  description = "Subnet prefix length per node for pod IPs (e.g. 23 gives each node a /23)."
  type        = number
}

# ── Worker Nodes ──────────────────────────────────────────────────────────────

variable "worker_instance_type" {
  description = "EC2 instance type for ROSA worker nodes. m5.xlarge is the ROSA minimum."
  type        = string
}

variable "worker_node_count" {
  description = "Number of worker nodes. 5 required for IBM Maximo Application Suite HA."
  type        = number
}

variable "worker_disk_size_gb" {
  description = "Root disk size in GB for each worker node. MAS requires at least 300 GB."
  type        = number
}

# ── DNS ───────────────────────────────────────────────────────────────────────

variable "base_domain" {
  description = "Custom DNS domain for the ROSA cluster (e.g. gilead.com)."
  type        = string
}

variable "create_hosted_zone" {
  description = "true = create new Route53 zone. false = reuse existing zone (set hosted_zone_id)."
  type        = bool
}

variable "hosted_zone_id" {
  description = "Existing Route53 zone ID. Used only when create_hosted_zone = false."
  type        = string
}

# ── Cluster Provisioning ──────────────────────────────────────────────────────

variable "machine_pool_name" {
  description = "Name of the additional machine pool for worker nodes."
  type        = string
}

variable "create_admin_user" {
  description = "Create a default cluster-admin user with a generated password."
  type        = bool
}

variable "private" {
  description = "Make cluster API and Ingress endpoints private (internal NLBs only)."
  type        = bool
}

variable "aws_private_link" {
  description = "Enable AWS PrivateLink so Red Hat SRE accesses the cluster without traversing the internet."
  type        = bool
}

variable "multi_az" {
  description = "Deploy control plane across multiple AZs. false = single-AZ control plane, workers in 2 AZs."
  type        = bool
}

variable "machine_pool_labels" {
  description = "Kubernetes labels applied to all nodes in the worker machine pool."
  type        = map(string)
}

variable "rhcs_url" {
  description = "Red Hat Cloud Services API endpoint."
  type        = string
}

# ── Backend ───────────────────────────────────────────────────────────────────

variable "state_lock_table" {
  description = "DynamoDB table name used for Terraform state locking. Must match the value used in CI."
  type        = string
}

# ── Tags ──────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Additional tags merged onto all taggable resources."
  type        = map(string)
}
