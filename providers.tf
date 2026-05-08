# ==============================================================================
# providers.tf -- Provider and Backend Configuration
#
# The S3 state bucket and DynamoDB lock table are bootstrapped automatically
# by the GitHub Actions workflow before the first terraform init.
# No manual steps required — the workflow handles the full bootstrap.
#
# Backend values are injected at runtime via -backend-config flags:
#   terraform init \
#     -backend-config="bucket=rosa-terraform-state-<ACCOUNT_ID>" \
#     -backend-config="key=<TF_STATE_KEY>" \
#     -backend-config="region=<aws_region>" \
#     -backend-config="dynamodb_table=<TF_LOCK_TABLE>" \
#     -backend-config="encrypt=true"
#
# RHCS Token:
#   Never hard-code the token. Set it as a GitHub Actions secret:
#     RHCS_TOKEN: ${{ secrets.RHCS_TOKEN }}
#   The rhcs provider reads it automatically from the RHCS_TOKEN env var.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = "~> 1.6"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Partial configuration — bucket, region, key, and dynamodb_table are
  # supplied via -backend-config flags by the CI workflow at terraform init.
  backend "s3" {}
}

# AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
        Cluster     = var.cluster_name
      },
      var.tags
    )
  }
}

# Red Hat Cloud Services Provider
# Token is read from the RHCS_TOKEN environment variable automatically.
# GitHub Actions: set RHCS_TOKEN as a repository secret.
# Local dev:      export RHCS_TOKEN=$(cat ~/.ocm-token)
provider "rhcs" {
  url = var.rhcs_url
}
