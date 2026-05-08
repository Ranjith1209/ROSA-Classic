# ==============================================================================
# modules/iam/main.tf
#
# Creates all IAM resources for ROSA Classic STS mode:
#
#   Installer Role    -- assumed by Red Hat installer
#   Support Role      -- assumed by Red Hat SRE
#   ControlPlane Role -- assumed by 3 master EC2 instances
#   Worker Role       -- assumed by 5 worker EC2 instances
#   ControlPlane Policy + Instance Profile
#   Worker Policy       + Instance Profile
#   OIDC Provider       -- enables IRSA (no long-lived IAM keys in cluster)
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition
}

# Installer Role -- trusted by Red Hat managed installer
resource "aws_iam_role" "installer" {
  name = "${var.cluster_name}-Installer-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:${local.partition}:iam::${var.redhat_account_id}:role/RH-Managed-OpenShift-Installer"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.cluster_name
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name         = "${var.cluster_name}-Installer-Role"
    rosa_managed = "true"
  })
}

resource "aws_iam_role_policy_attachment" "installer" {
  role       = aws_iam_role.installer.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}

# Support Role -- trusted by Red Hat SRE
resource "aws_iam_role" "support" {
  name = "${var.cluster_name}-Support-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:${local.partition}:iam::${var.redhat_account_id}:role/RH-Technical-Support-Access"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.cluster_name
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name         = "${var.cluster_name}-Support-Role"
    rosa_managed = "true"
  })
}

resource "aws_iam_role_policy_attachment" "support" {
  role       = aws_iam_role.support.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/job-function/SupportUser"
}

# ControlPlane Role -- assumed by 3 master EC2 instances
resource "aws_iam_role" "control_plane" {
  name = "${var.cluster_name}-ControlPlane-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name         = "${var.cluster_name}-ControlPlane-Role"
    rosa_managed = "true"
  })
}

resource "aws_iam_policy" "control_plane" {
  name        = "${var.cluster_name}-ControlPlane-Policy"
  description = "Permissions for ROSA Classic control plane nodes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:AttachVolume", "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateSecurityGroup", "ec2:CreateTags", "ec2:CreateVolume",
        "ec2:DeleteSecurityGroup", "ec2:DeleteVolume", "ec2:Describe*",
        "ec2:DetachVolume", "ec2:ModifyInstanceAttribute", "ec2:ModifyVolume",
        "ec2:RevokeSecurityGroupIngress",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:AttachLoadBalancerToSubnets",
        "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancerListeners",
        "elasticloadbalancing:CreateLoadBalancerPolicy",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancerListeners",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
        "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
        "kms:DescribeKey",
        "route53:ChangeResourceRecordSets",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "s3:GetBucketLocation", "s3:GetEncryptionConfiguration",
        "s3:ListBucket", "s3:PutObject", "s3:GetObject", "s3:DeleteObject",
        "sts:AssumeRole"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "control_plane" {
  role       = aws_iam_role.control_plane.name
  policy_arn = aws_iam_policy.control_plane.arn
}

resource "aws_iam_instance_profile" "control_plane" {
  name = "${var.cluster_name}-ControlPlane-Profile"
  role = aws_iam_role.control_plane.name

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-ControlPlane-Profile"
  })
}

# Worker Role -- assumed by 5 worker EC2 instances
resource "aws_iam_role" "worker" {
  name = "${var.cluster_name}-Worker-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name         = "${var.cluster_name}-Worker-Role"
    rosa_managed = "true"
  })
}

resource "aws_iam_policy" "worker" {
  name        = "${var.cluster_name}-Worker-Policy"
  description = "Permissions for ROSA Classic worker nodes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances", "ec2:DescribeRegions",
        "ec2:DescribeRouteTables", "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets", "ec2:DescribeVolumes",
        "ec2:CreateSecurityGroup", "ec2:CreateTags", "ec2:CreateVolume",
        "ec2:ModifyInstanceAttribute", "ec2:ModifyVolume",
        "ec2:AttachVolume", "ec2:DetachVolume", "ec2:DeleteVolume",
        "s3:GetObject", "s3:ListBucket", "s3:PutObject",
        "s3:DeleteObject", "s3:GetBucketLocation",
        "sts:AssumeRole"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker" {
  role       = aws_iam_role.worker.name
  policy_arn = aws_iam_policy.worker.arn
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.cluster_name}-Worker-Profile"
  role = aws_iam_role.worker.name

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-Worker-Profile"
  })
}

# OIDC Provider -- registers Red Hat's hosted OIDC issuer in AWS IAM
# Enables IRSA: operator pod JWT -> STS -> short-lived credentials (no IAM keys)
resource "aws_iam_openid_connect_provider" "rosa" {
  url             = "https://rh-oidc.s3.${var.aws_region}.amazonaws.com/${var.cluster_name}"
  client_id_list  = ["openshift", "sts.amazonaws.com"]
  thumbprint_list = [var.oidc_thumbprint]

  tags = merge(var.tags, {
    Name         = "${var.cluster_name}-oidc-provider"
    rosa_managed = "true"
  })
}
