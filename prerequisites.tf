# ==============================================================================
# prerequisites.tf — Preflight Validation
#
# Runs checks BEFORE the ROSA cluster is created to catch common new-account
# issues early (better to fail at minute 0 than at minute 44 of a cluster apply).
#
# Checks:
#   1. Requested AZs actually exist in the selected region
#   2. RHCS_TOKEN environment variable is set
#   3. ROSA CLI quota + permissions check (if rosa CLI is installed)
#
# null_resource produces no AWS resources — local-exec only.
# The rosa module depends_on null_resource.rosa_preflight_check.
# ==============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# Check 1: AZ validation
resource "null_resource" "az_validation" {
  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      echo "=== Preflight: Validating availability zones ==="
      FAILS=0
      for AZ in ${join(" ", var.availability_zones)}; do
        aws ec2 describe-availability-zones \
          --region ${var.aws_region} \
          --filter "Name=zone-name,Values=$AZ" \
          --query 'AvailabilityZones[0].State' \
          --output text 2>/dev/null | grep -q "available" \
        && echo "  OK: $AZ is available" \
        || { echo "  ERROR: $AZ not available in ${var.aws_region}"; FAILS=$((FAILS+1)); }
      done
      [ $FAILS -eq 0 ] || exit 1
    EOT
  }
}

# Check 2: RHCS token
resource "null_resource" "rhcs_token_check" {
  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      echo "=== Preflight: Checking RHCS_TOKEN ==="
      if [ -z "$RHCS_TOKEN" ]; then
        echo "  ERROR: RHCS_TOKEN is not set."
        echo "  Get it from: https://console.redhat.com/openshift/token"
        echo "  GitHub Actions: add RHCS_TOKEN as a repository secret."
        exit 1
      fi
      echo "  OK: RHCS_TOKEN is set"
    EOT
  }
}

# Check 3: ROSA CLI quota and permissions (skipped gracefully if rosa not installed)
resource "null_resource" "rosa_preflight_check" {
  depends_on = [
    null_resource.az_validation,
    null_resource.rhcs_token_check,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      echo "=== Preflight: ROSA checks ==="
      if ! command -v rosa >/dev/null 2>&1; then
        echo "  WARNING: rosa CLI not found — skipping quota/permissions checks."
        echo "  Install from: https://console.redhat.com/openshift/downloads"
        exit 0
      fi
      echo "  rosa CLI: $(rosa version)"
      rosa login --token="$RHCS_TOKEN" 2>&1 || { echo "  ERROR: OCM login failed"; exit 1; }
      rosa verify quota --region=${var.aws_region} 2>&1 \
        && echo "  OK: AWS quotas verified" \
        || { echo "  ERROR: Quota check failed"; exit 1; }
      rosa verify permissions --region=${var.aws_region} 2>&1 \
        && echo "  OK: IAM permissions verified" \
        || { echo "  ERROR: Permissions check failed"; exit 1; }
      echo "=== All preflight checks passed ==="
    EOT
  }
}
