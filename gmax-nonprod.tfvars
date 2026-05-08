# ==============================================================================
# gmax-nonprod.tfvars — Non-Production Environment Variable Values
#
# Loaded explicitly (NOT auto-loaded by Terraform):
#   terraform plan  -var-file=gmax-nonprod.tfvars
#   terraform apply -var-file=gmax-nonprod.tfvars
#
# GitHub Actions usage:
#   - Non-sensitive values live here (committed to repo)
#   - Sensitive values come from GitHub Actions secrets:
#       RHCS_TOKEN: ${{ secrets.RHCS_TOKEN }}
#
# Do NOT put rhcs_token or admin passwords in this file.
# ==============================================================================

# ── Core ──────────────────────────────────────────────────────────────────────
aws_region        = "us-west-1"
cluster_name      = "gmax-nonprod"
openshift_version = "4.20.18"
environment       = "Non-Prod"
project_name      = "MAS-ROSA"

# ── Networking ────────────────────────────────────────────────────────────────
vpc_cidr = "10.0.0.0/16"

# Exactly 2 AZs (multi_az = false, but workers span both private subnets)
availability_zones = ["us-west-1b", "us-west-1b"]

# 2 private subnets — one per AZ — ROSA masters and workers run here
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

# 1 public subnet — NAT Gateway only, no workloads
public_subnet_cidr = "10.0.100.0/24"

# Subnet names (AWS Name tags)
master_subnet_name = "SN-01-NonProd-Master"
worker_subnet_name = "SN-01-NonProd-Worker"
public_subnet_name = "SN-01-NonProd-Public"

# ── OpenShift Networking ──────────────────────────────────────────────────────
service_cidr = "172.30.0.0/16"
pod_cidr     = "10.128.0.0/14"
host_prefix  = 23

# ── Worker Nodes ──────────────────────────────────────────────────────────────
worker_instance_type = "m5.4xlarge"
worker_node_count    = 5
worker_disk_size_gb  = 300

# ── Cluster Provisioning ──────────────────────────────────────────────────────
machine_pool_name = "worker-pool"
create_admin_user = true
private           = true
aws_private_link  = true
multi_az          = false

machine_pool_labels = {
  "node-role.kubernetes.io/worker" = ""
  "mas-workload"                   = "true"
}

# ── RHCS ──────────────────────────────────────────────────────────────────────
rhcs_url = "https://api.openshift.com"

# ── DNS ───────────────────────────────────────────────────────────────────────
base_domain        = "gilead.com"
create_hosted_zone = true
hosted_zone_id     = ""

# After first apply, run:
#   terraform output route53_ns_records
# Then add those 4 NS records at your domain registrar for gilead.com.

# ── Backend ───────────────────────────────────────────────────────────────────
state_lock_table = "rosa-terraform-lock"

# ── Tags ──────────────────────────────────────────────────────────────────────
tags = {
  Owner       = "terraform"
  Environment = "dev"
  Domain      = "gilead"
}
