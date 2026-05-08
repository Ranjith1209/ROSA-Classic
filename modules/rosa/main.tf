# ==============================================================================
# modules/rosa/main.tf
#
# Creates the ROSA Classic private cluster and associated resources:
#
#   rhcs_cluster_rosa_classic  -- the cluster itself (~40 min first apply)
#   rhcs_machine_pool          -- worker node pool
#   random_password            -- auto-generated admin password
#   rhcs_identity_provider     -- HTPasswd IDP (initial access)
#
# Key cluster flags (all driven by variables — no hardcoded booleans):
#   private                  -- API + Ingress NLBs are internal only
#   aws_private_link         -- Red Hat SRE access via AWS PrivateLink
#   multi_az                 -- control-plane AZ spread
#   wait_for_create_complete -- blocks until cluster reaches ready state
# ==============================================================================

data "aws_caller_identity" "current" {}

resource "rhcs_cluster_rosa_classic" "this" {
  name           = var.cluster_name
  cloud_region   = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id
  version        = var.openshift_version

  availability_zones = var.availability_zones
  aws_subnet_ids     = var.private_subnet_ids
  machine_cidr       = var.vpc_cidr
  service_cidr       = var.service_cidr
  pod_cidr           = var.pod_cidr
  host_prefix        = var.host_prefix

  private          = var.private
  aws_private_link = var.aws_private_link
  multi_az         = var.multi_az

  compute_machine_type     = var.worker_instance_type
  replicas                 = var.worker_node_count
  wait_for_create_complete = var.wait_for_create_complete
  create_admin_user        = var.create_admin_user

  sts = {
    managed_policies     = var.managed_policies
    operator_role_prefix = var.cluster_name
    role_arn             = var.installer_role_arn
    support_role_arn     = var.support_role_arn

    instance_iam_roles = {
      master_role_arn = var.control_plane_role_arn
      worker_role_arn = var.worker_role_arn
    }

    oidc_endpoint_url = var.oidc_endpoint_url
  }

  properties = {
    rosa_creator_arn = data.aws_caller_identity.current.arn
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [version]
  }
}

# Additional machine pool for worker nodes
resource "rhcs_machine_pool" "workers" {
  cluster      = rhcs_cluster_rosa_classic.this.id
  name         = var.machine_pool_name
  machine_type = var.worker_instance_type
  replicas     = var.worker_node_count
  disk_size    = var.worker_disk_size_gb

  labels = var.machine_pool_labels

  depends_on = [rhcs_cluster_rosa_classic.this]
}
