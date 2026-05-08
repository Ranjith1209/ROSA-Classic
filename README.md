# Gilead MAS-ROSA — ROSA Classic Private Cluster (Terraform)

Terraform infrastructure-as-code for deploying **Red Hat OpenShift Service on AWS (ROSA) Classic** private clusters for the **Maximo Application Suite (MAS)** platform at Gilead Sciences. All provisioning, approval gates, and teardown are managed through a single GitHub Actions workflow — no manual `terraform` commands required in normal operations.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Environments](#environments)
4. [Software Versions](#software-versions)
5. [Repository Structure](#repository-structure)
6. [Modules](#modules)
7. [All Input Variables](#all-input-variables)
8. [Terraform Outputs](#terraform-outputs)
9. [GitHub Secrets & Variables](#github-secrets--variables)
10. [CI/CD Workflow — Step-by-Step](#cicd-workflow--step-by-step)
11. [First-Time Setup](#first-time-setup)
12. [Post-Apply Steps](#post-apply-steps)
13. [Destroy Guide](#destroy-guide)
14. [State Management](#state-management)
15. [Tags Applied to All Resources](#tags-applied-to-all-resources)
16. [Troubleshooting](#troubleshooting)

---

## Overview

This project provisions a **fully private ROSA Classic cluster** using STS (Security Token Service) mode. The cluster runs inside a private VPC with no public endpoints — all access is through AWS PrivateLink or a VPN/Direct Connect connection.

**What gets created:**

- VPC with private subnets, a single NAT Gateway, and 6 VPC endpoints
- 4 IAM roles (Installer, Support, ControlPlane, Worker) and an OIDC provider for IRSA
- Route53 public hosted zone for `gilead.com`
- ROSA Classic cluster with a dedicated machine pool
- An HTPasswd cluster-admin user
- S3 bucket + DynamoDB table for Terraform remote state (auto-bootstrapped)

**What does NOT get created manually:**

The S3 state bucket and DynamoDB lock table are bootstrapped automatically by the GitHub Actions workflow on the first run. No manual setup is needed.

---

## Architecture

```
                         Internet
                             |
                    Internet Gateway
                             |
         ┌───────────────────────────────────────────────┐
         │          VPC: 10.0.0.0/16  ({cluster}-vpc)    │
         │                                                │
         │  ┌──────────────────────────────────────────┐ │
         │  │  Public Subnet (10.0.100.0/24)           │ │
         │  │  SN-01-NonProd-Public  (NAT GW only)     │ │
         │  │           │                              │ │
         │  │       NAT Gateway  ──────► Elastic IP    │ │
         │  └───────────┼──────────────────────────────┘ │
         │              │  (outbound only)                │
         │  ┌───────────┼──────────────────────────────┐ │
         │  │  Private Subnet A (10.0.1.0/24)  AZ-1   │ │
         │  │  SN-01-NonProd-Master                    │ │
         │  │  ROSA Control Plane + Workers            │ │
         │  └──────────────────────────────────────────┘ │
         │  ┌──────────────────────────────────────────┐ │
         │  │  Private Subnet B (10.0.2.0/24)  AZ-2   │ │
         │  │  SN-01-NonProd-Worker                    │ │
         │  │  ROSA Worker Nodes                       │ │
         │  └──────────────────────────────────────────┘ │
         │                                                │
         │  VPC Endpoints (private, no internet needed)  │
         │    S3 (Gateway) · EC2 · STS · ELB             │
         │    ECR-API · ECR-DKR                           │
         │                                                │
         └────────────────────────────────────────────────┘
                             │
                    AWS PrivateLink
                             │
              Red Hat OpenShift Cluster Manager
```

> **Access model:** The cluster API and console are not reachable from the public internet. Access requires a VPN, AWS Direct Connect, or AWS PrivateLink connection into the VPC.

---

## Environments

Three independent environments are supported. Each has its own:

- `.tfvars` file with non-sensitive configuration
- Separate Terraform state file in S3 (`rosa/<environment>/terraform.tfstate`)
- GitHub Environment for approval gates

| Environment | File | Cluster Name | Purpose |
|---|---|---|---|
| `gmax-nonprod` | `gmax-nonprod.tfvars` | `gmax-nonprod` | Development / Integration testing |
| `gmax-val` | `gmax-val.tfvars` | `gmax-val` | Validation / UAT |
| `gmax-prod` | `gmax-prod.tfvars` | `gmax-prod` | Production |

> The `environment` variable in each `.tfvars` file must match: `"Non-Prod"`, `"Val"`, or `"Prod"`.

---

## Software Versions

| Component | Version | Notes |
|---|---|---|
| Terraform | `>= 1.5.0` (workflow uses `1.6.6`) | Set via `TF_VERSION` GitHub variable |
| AWS Provider (`hashicorp/aws`) | `~> 5.0` | |
| RHCS Provider (`terraform-redhat/rhcs`) | `~> 1.6` | Red Hat Cloud Services |
| Random Provider (`hashicorp/random`) | `~> 3.5` | Used for admin password generation |
| Null Provider (`hashicorp/null`) | `~> 3.2` | Used for preflight checks |
| OpenShift (ROSA) | `4.20.18` | Per-environment, set in `.tfvars` |
| AWS CLI | `>= 2.x` | Required locally and in CI |
| ROSA CLI | `latest` | Auto-installed in CI preflight job |
| GitHub Actions runner | `ubuntu-latest` | All CI jobs |
| `actions/checkout` | `v4` | |
| `hashicorp/setup-terraform` | `v3` | |
| `actions/upload-artifact` | `v4` | |
| `actions/download-artifact` | `v4` | |

---

## Repository Structure

```
rosa-classic-private-cluster/
│
├── .github/
│   └── workflows/
│       └── terraform.yml          # Single workflow: plan → preflight → approve → apply/destroy
│
├── modules/
│   ├── vpc/                       # VPC, subnets, NAT GW, VPC endpoints
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── iam/                       # IAM roles, instance profiles, OIDC provider
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── dns/                       # Route53 hosted zone (create or look up existing)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── rosa/                      # ROSA Classic cluster + machine pool
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
│
├── backend.tf                     # S3 + DynamoDB backend resources
├── main.tf                        # Root module — wires the 4 sub-modules together
├── outputs.tf                     # Root-level outputs
├── prerequisites.tf               # Preflight validation (AZ check, token check)
├── providers.tf                   # Provider + backend configuration
├── variables.tf                   # All variable declarations
│
├── terraform.tfvars               # Intentionally empty (values come from -var-file)
├── gmax-nonprod.tfvars            # Non-production values (committed)
├── gmax-val.tfvars                # Validation values (committed)
└── gmax-prod.tfvars               # Production values (committed)
```

---

## Modules

### `module.vpc` — Networking

Creates the full AWS network stack:

| Resource | Details |
|---|---|
| VPC | CIDR from `var.vpc_cidr` (e.g. `10.0.0.0/16`) |
| Private Subnet A | `private_subnet_cidrs[0]`, AZ from `availability_zones[0]` |
| Private Subnet B | `private_subnet_cidrs[1]`, AZ from `availability_zones[1]` |
| Public Subnet | `var.public_subnet_cidr`, hosts NAT Gateway only |
| Internet Gateway | Attached to VPC for outbound NAT traffic |
| Elastic IP | Static public IP for NAT Gateway |
| NAT Gateway | Single shared gateway in the public subnet |
| Route Tables | Separate tables for public (IGW) and private (NAT GW) subnets |
| VPC Endpoint — S3 | Gateway endpoint (free, no ENI) |
| VPC Endpoint — EC2 | Interface endpoint with private DNS |
| VPC Endpoint — STS | Interface endpoint with private DNS |
| VPC Endpoint — ELB | Interface endpoint with private DNS |
| VPC Endpoint — ECR API | Interface endpoint with private DNS |
| VPC Endpoint — ECR DKR | Interface endpoint with private DNS |

> VPC endpoints allow ROSA nodes to reach AWS services without internet traffic, even in a fully private cluster.

---

### `module.iam` — Identity & Access Management

Creates STS-mode IAM roles that Red Hat assumes to manage the cluster lifecycle:

| Role | Assumed By | Purpose |
|---|---|---|
| Installer Role | Red Hat managed installer (`arn:aws:iam::710019948333:root`) | Creates/deletes cluster infrastructure |
| Support Role | Red Hat SRE team | Break-glass access for incident response |
| ControlPlane Role | EC2 instances (control plane) | Describe EC2, manage ELBs, Route53, S3 access |
| Worker Role | EC2 instances (worker nodes) | Describe EC2, manage EBS volumes, S3 read/write |

Also creates:
- **Instance profiles** for ControlPlane and Worker roles
- **OIDC Provider** — enables IRSA (IAM Roles for Service Accounts) so cluster operators can assume IAM roles via short-lived tokens

---

### `module.dns` — Route53

Manages DNS for the cluster's base domain.

| Mode | Condition | Behavior |
|---|---|---|
| Create new zone | `create_hosted_zone = true` | Creates a new Route53 public hosted zone |
| Use existing zone | `create_hosted_zone = false` | Looks up zone by `hosted_zone_id` |

> After first apply with a new zone, you must add the 4 NS records output by `route53_ns_records` to your domain registrar for `gilead.com`.

---

### `module.rosa` — ROSA Classic Cluster

Provisions the OpenShift cluster via the RHCS Terraform provider:

| Component | Details |
|---|---|
| Cluster type | ROSA Classic (STS mode) |
| Network access | Private (`private = true`, `aws_private_link = true`) |
| Control plane | Single-AZ by default (`multi_az = false`) |
| Worker nodes | Configurable instance type, count, and disk size |
| Machine pool | Named pool with custom labels for MAS workloads |
| Admin user | HTPasswd user created when `create_admin_user = true` |
| Cluster version | Set via `openshift_version` in `.tfvars` |

> First apply blocks for **35–45 minutes** while ROSA provisions the cluster. The GitHub Actions job timeout is set to 90 minutes to accommodate this.

---

## All Input Variables

All variables are declared in `variables.tf`. Non-sensitive values live in the `.tfvars` file for each environment. Sensitive values (`rhcs_token`) come from GitHub Secrets and are never committed to the repository.

### Core

| Variable | Type | Example | Description |
|---|---|---|---|
| `aws_region` | string | `"us-west-1"` | AWS region where the cluster is deployed |
| `cluster_name` | string | `"gmax-nonprod"` | Name applied to all resources and the ROSA cluster |
| `openshift_version` | string | `"4.20.18"` | OpenShift version to install |
| `environment` | string | `"Non-Prod"` | Must be one of: `Non-Prod`, `Val`, `Prod` |
| `project_name` | string | `"MAS-ROSA"` | Project tag applied to all resources |

### Networking

| Variable | Type | Example | Description |
|---|---|---|---|
| `vpc_cidr` | string | `"10.0.0.0/16"` | CIDR block for the VPC |
| `availability_zones` | list(string) | `["us-west-1b", "us-west-1b"]` | Exactly 2 AZs (required by ROSA) |
| `private_subnet_cidrs` | list(string) | `["10.0.1.0/24", "10.0.2.0/24"]` | Exactly 2 private subnet CIDRs |
| `public_subnet_cidr` | string | `"10.0.100.0/24"` | 1 public subnet for the NAT Gateway |
| `master_subnet_name` | string | `"SN-01-NonProd-Master"` | AWS Name tag for the primary private subnet |
| `worker_subnet_name` | string | `"SN-01-NonProd-Worker"` | AWS Name tag for the secondary private subnet |
| `public_subnet_name` | string | `"SN-01-NonProd-Public"` | AWS Name tag for the public subnet |

### OpenShift Networking

| Variable | Type | Example | Description |
|---|---|---|---|
| `service_cidr` | string | `"172.30.0.0/16"` | CIDR for OpenShift service network (ClusterIP range) |
| `pod_cidr` | string | `"10.128.0.0/14"` | CIDR for pod overlay network |
| `host_prefix` | number | `23` | Subnet prefix length allocated to each node (`/23` = 512 IPs per node) |

### Worker Nodes

| Variable | Type | Example | Description |
|---|---|---|---|
| `worker_instance_type` | string | `"m5.4xlarge"` | EC2 instance type for worker nodes (16 vCPU / 64 GB) |
| `worker_node_count` | number | `5` | Number of worker nodes in the default machine pool |
| `worker_disk_size_gb` | number | `300` | Root volume size per worker node (GB) |

### Cluster Provisioning

| Variable | Type | Example | Description |
|---|---|---|---|
| `machine_pool_name` | string | `"worker-pool"` | Name of the ROSA machine pool |
| `machine_pool_labels` | map(string) | `{"mas-workload": "true", ...}` | Kubernetes labels applied to worker nodes |
| `create_admin_user` | bool | `true` | Whether to create an HTPasswd cluster-admin user |
| `private` | bool | `true` | Make the cluster private (no public API endpoint) |
| `aws_private_link` | bool | `true` | Enable AWS PrivateLink for the cluster |
| `multi_az` | bool | `false` | Spread control plane across multiple AZs |

### DNS

| Variable | Type | Example | Description |
|---|---|---|---|
| `base_domain` | string | `"gilead.com"` | Base domain for the cluster (`apps.<cluster>.<domain>`) |
| `create_hosted_zone` | bool | `true` | Create a new Route53 zone (`true`) or use existing (`false`) |
| `hosted_zone_id` | string | `""` | Existing zone ID — used when `create_hosted_zone = false` |

### RHCS

| Variable | Type | Example | Description |
|---|---|---|---|
| `rhcs_url` | string | `"https://api.openshift.com"` | Red Hat Cloud Services API endpoint |

### Backend

| Variable | Type | Example | Description |
|---|---|---|---|
| `state_lock_table` | string | `"rosa-terraform-lock"` | DynamoDB table name for Terraform state locking |

### Tags

| Variable | Type | Example | Description |
|---|---|---|---|
| `tags` | map(string) | `{Owner = "terraform", Domain = "gilead"}` | Additional AWS tags merged with default provider tags |

---

## Terraform Outputs

Run `terraform output` after a successful apply to retrieve these values:

| Output | Sensitive | Description |
|---|---|---|
| `vpc_id` | No | VPC resource ID |
| `private_subnet_ids` | No | List of private subnet IDs (ROSA nodes run here) |
| `public_subnet_id` | No | Public subnet ID (NAT Gateway only) |
| `nat_gateway_public_ip` | No | Public IP of the NAT Gateway — add to allowlists for outbound ROSA traffic |
| `installer_role_arn` | No | Installer IAM Role ARN |
| `support_role_arn` | No | Support IAM Role ARN |
| `control_plane_role_arn` | No | ControlPlane IAM Role ARN |
| `worker_role_arn` | No | Worker IAM Role ARN |
| `oidc_provider_url` | No | OIDC provider URL for IRSA |
| `cluster_id` | No | ROSA Cluster ID (Red Hat OCM resource ID) |
| `cluster_api_url` | No | Cluster API endpoint (requires VPN/PrivateLink) |
| `cluster_console_url` | No | OpenShift web console URL (requires VPN/PrivateLink) |
| `admin_username` | No | HTPasswd cluster-admin username |
| `admin_password` | **Yes** | Cluster-admin password — retrieve with `terraform output -raw admin_password` |
| `route53_zone_id` | No | Route53 hosted zone ID |
| `route53_ns_records` | No | NS records to add at the domain registrar after first apply |

---

## GitHub Secrets & Variables

Configure these before running the workflow for the first time.

### Repository Secrets

Go to **Settings → Secrets and variables → Actions → Secrets**:

| Secret Name | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS access key with permissions to create VPC, IAM, ROSA, Route53, S3, DynamoDB resources |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for the above |
| `TF_VAR_RHCS_TOKEN` | Red Hat OCM token — get it from [console.redhat.com/openshift/token](https://console.redhat.com/openshift/token) |

### Repository Variables (Optional)

Go to **Settings → Secrets and variables → Actions → Variables**:

| Variable Name | Default | Description |
|---|---|---|
| `TF_VERSION` | `1.6.6` | Terraform version to install in CI |
| `TF_LOCK_TABLE` | `rosa-terraform-lock` | DynamoDB table name for state locking |
| `AWS_DEFAULT_REGION` | `us-west-1` | Fallback region if not found in `.tfvars` |

### GitHub Environments

The workflow uses GitHub Environments for approval gates. Create these three environments under **Settings → Environments**:

| Environment Name | Required Reviewers | Purpose |
|---|---|---|
| `gmax-nonprod` | Optional (or 1 reviewer) | Gates apply/destroy for non-production |
| `gmax-val` | Recommended: 1 reviewer | Gates apply/destroy for validation |
| `gmax-prod` | Required: 1+ reviewer | Gates apply/destroy for production |

> When an approver is configured, the workflow pauses after the Plan and Preflight jobs and displays a **"Review deployments"** button. Nothing is applied or destroyed until a reviewer clicks Approve.

---

## CI/CD Workflow — Step-by-Step

The workflow is triggered manually from the **Actions** tab. No commands need to be run locally.

### How to trigger

1. Go to the repository on GitHub
2. Click **Actions** → **Terraform** (left sidebar)
3. Click **Run workflow** (top right)
4. Select:
   - **Target environment**: `gmax-nonprod`, `gmax-val`, or `gmax-prod`
   - **Operation mode**: `apply` or `destroy`
5. Click **Run workflow**

---

### Apply Flow

```
Trigger (workflow_dispatch)
        │
        ▼
┌─────────────────┐
│   Job 1: Plan   │  Runs on ubuntu-latest
│                 │
│  1. Checkout    │
│  2. Setup TF    │
│  3. Resolve     │
│     backend     │  Reads aws_region from .tfvars, computes S3 bucket name
│  4. Bootstrap   │
│     S3 bucket   │  Creates bucket (first run) with versioning + encryption
│  5. Bootstrap   │
│     DynamoDB    │  Creates lock table if missing
│  6. TF Init     │  -backend-config flags injected at runtime
│  7. Import      │
│     backend     │  Imports S3/DynamoDB into state so plan shows no drift
│  8. TF Validate │
│  9. TF Plan     │  Saves plan to artifact: tfplan-{env}-apply
│ 10. Upload      │
│     artifact    │
└────────┬────────┘
         │ success
         ▼
┌─────────────────────┐
│  Job 2: Preflight   │  Runs on ubuntu-latest (apply mode only)
│                     │
│  1. Install         │
│     ROSA CLI        │  Downloads latest from mirror.openshift.com
│  2. ROSA login      │  Authenticates with RHCS_TOKEN
│  3. Verify quotas   │  rosa verify quota --region=<region>
│  4. Verify IAM      │  rosa verify permissions --region=<region>
│     permissions     │
└──────────┬──────────┘
           │ success
           ▼
┌───────────────────────────────┐
│  ⏸  APPROVAL GATE            │
│  (GitHub Environment review)  │  Reviewer sees plan summary and preflight results
│  Click "Approve" to continue  │
└──────────────┬────────────────┘
               │ approved
               ▼
┌─────────────────────────────────┐
│  Job 3: Apply [{environment}]   │  Runs on ubuntu-latest
│                                 │
│  1. Checkout                    │
│  2. Setup TF                    │
│  3. Resolve backend config      │
│  4. TF Init                     │
│  5. Download plan artifact      │  Exact same plan reviewed in Job 1
│  6. TF Apply (tfplan)           │  Applies exactly what was planned
│                                 │  (~35–45 min for ROSA cluster)
└─────────────────────────────────┘
```

---

### Destroy Flow

```
Trigger (workflow_dispatch, mode=destroy)
        │
        ▼
┌──────────────────────────────────────┐
│   Job 1: Plan [destroy]              │  Runs on ubuntu-latest
│                                      │
│  1. Checkout + Setup TF              │
│  2. Resolve backend config           │
│  3. Bootstrap DynamoDB               │  Recreates table if a prior failed
│                                      │  destroy deleted it
│  FIX 1: Remove prevent_destroy       │  Strips lifecycle guard from backend.tf
│  FIX 2: Restore tfstate from S3      │  Recovers state from S3 versioning
│          versioning if deleted       │  if the object was accidentally deleted
│  FIX 3: Clear stale DynamoDB         │  Removes stale md5 checksum entry
│          checksum                    │  that blocks terraform init
│  FIX 4: Force unlock stale lock      │  Deletes DynamoDB lock item from a
│                                      │  previously interrupted run
│  FIX 5: Pre-destroy VPC cleanup      │  Deletes NAT GW, VPC Endpoints, IGW,
│                                      │  and EIPs before TF runs — these would
│                                      │  otherwise block subnet deletion
│  6. TF Init (-reconfigure)           │
│  FIX 6: Remove backend resources     │  Removes S3/DynamoDB from TF state so
│          from state                  │  destroy does not delete the state bucket
│  7. Verify TF state (not empty)      │
│  8. TF Plan -destroy                 │  Saves plan to tfplan-{env}-destroy
│  9. Upload artifact                  │
└────────────────────┬─────────────────┘
                     │ success
                     │ (preflight skipped for destroy)
                     ▼
     ┌───────────────────────────────┐
     │  ⏸  APPROVAL GATE            │
     │  (GitHub Environment review)  │
     └──────────────┬────────────────┘
                    │ approved
                    ▼
     ┌──────────────────────────────────────┐
     │  Job 3: Destroy [{environment}]      │
     │                                      │
     │  1. Checkout + Setup TF              │
     │  2. Resolve backend config           │
     │  3. TF Init (-reconfigure)           │
     │  4. Download plan artifact           │
     │  5. TF Apply (destroy plan)          │  Destroys exactly what was planned
     └──────────────────────────────────────┘
```

> **State safety:** The S3 state bucket and DynamoDB lock table are deliberately excluded from destroy. They persist across environment teardowns so state for other environments is never lost.

---

## First-Time Setup

### 1. Create GitHub Environments

In your GitHub repository:

1. Go to **Settings → Environments → New environment**
2. Create: `gmax-nonprod`, `gmax-val`, `gmax-prod`
3. For each environment, optionally add **Required reviewers** under "Deployment protection rules"

### 2. Add GitHub Secrets

Go to **Settings → Secrets and variables → Actions**:

```
AWS_ACCESS_KEY_ID       = <your-aws-access-key>
AWS_SECRET_ACCESS_KEY   = <your-aws-secret-key>
TF_VAR_RHCS_TOKEN       = <your-red-hat-ocm-token>
```

Get your Red Hat OCM token at: [console.redhat.com/openshift/token](https://console.redhat.com/openshift/token)

### 3. Enable ROSA in AWS (One-time per account)

```bash
rosa login --token=<your-rhcs-token>
rosa init
```

> `rosa init` enables the ROSA service in your AWS account. This only needs to be done once.

### 4. Run the workflow

Go to **Actions → Terraform → Run workflow**, select `gmax-nonprod` + `apply`, and click **Run workflow**.

The S3 bucket and DynamoDB table are created automatically on the first run.

---

## Post-Apply Steps

### Get cluster credentials

```bash
# From workflow outputs (in the Apply job logs):
terraform output cluster_console_url
terraform output cluster_api_url
terraform output admin_username
terraform output -raw admin_password
```

Or from GitHub Actions — expand the **Terraform Execute** step in the Apply job to see the outputs.

### Add DNS NS records (new Route53 zone only)

If `create_hosted_zone = true`, the workflow output includes 4 NS records:

```
terraform output route53_ns_records
```

Add these NS records at your domain registrar for `gilead.com`. OpenShift application routes (`*.apps.<cluster>.<domain>`) will not resolve until this is done.

### Access the cluster

The cluster is private — you must be on the corporate VPN or AWS Direct Connect:

```bash
# Login via oc CLI
oc login <cluster_api_url> \
  --username <admin_username> \
  --password <admin_password>

# Verify nodes are ready
oc get nodes

# Check cluster operators
oc get co

# Verify storage class (gp3 required for MAS)
oc get storageclass
```

### Verify MAS node requirements

| Requirement | Configured value |
|---|---|
| Instance type | `m5.4xlarge` (16 vCPU / 64 GB RAM) |
| Worker count | `5` |
| Root disk | `300 GB` |
| Network | Private with PrivateLink |
| OpenShift version | `4.20.18` |
| Storage class | `gp3` (default ROSA) |

---

## Destroy Guide

### Via GitHub Actions (recommended)

1. Go to **Actions → Terraform → Run workflow**
2. Select the environment and mode = `destroy`
3. Click **Run workflow**
4. The plan job runs 6 automated pre-flight fixes to handle common destroy failures
5. Review the plan at the approval gate, then approve

### What gets destroyed

- ROSA cluster (machine pool, admin user)
- IAM roles and instance profiles
- OIDC provider
- VPC (subnets, NAT GW, VPC endpoints, IGW, route tables)
- Route53 hosted zone (if it was created by Terraform)

### What is preserved

- **S3 state bucket** — shared across environments, never deleted by Terraform
- **DynamoDB lock table** — shared across environments, never deleted by Terraform

---

## State Management

State is stored per environment in S3:

| Environment | State Path |
|---|---|
| gmax-nonprod | `s3://rosa-terraform-state-<ACCOUNT_ID>/rosa/gmax-nonprod/terraform.tfstate` |
| gmax-val | `s3://rosa-terraform-state-<ACCOUNT_ID>/rosa/gmax-val/terraform.tfstate` |
| gmax-prod | `s3://rosa-terraform-state-<ACCOUNT_ID>/rosa/gmax-prod/terraform.tfstate` |

S3 bucket features:
- **Versioning enabled** — previous state versions are retained for recovery
- **AES-256 server-side encryption** — state is encrypted at rest
- **Public access blocked** — no public read/write access
- **DynamoDB locking** — prevents concurrent `apply` or `destroy` runs

---

## Tags Applied to All Resources

The AWS provider merges these default tags onto every resource, in addition to any per-environment `tags` map:

| Tag Key | Value | Source |
|---|---|---|
| `Project` | `MAS-ROSA` | `var.project_name` |
| `Environment` | `Non-Prod` / `Val` / `Prod` | `var.environment` |
| `ManagedBy` | `Terraform` | Hard-coded in provider |
| `Cluster` | `gmax-nonprod` / etc. | `var.cluster_name` |
| `Owner` | `terraform` | `var.tags` |
| `Domain` | `gilead` | `var.tags` |

---

## Troubleshooting

### Workflow fails at Preflight — quota or permissions error

```
rosa verify quota: insufficient quota
```

Request a service quota increase in AWS Console under **Service Quotas → EC2** for the relevant instance type (`m5.4xlarge`) in the target region. The number of vCPUs needed is `worker_node_count × 16`.

---

### Plan fails: `environment must be one of: Non-Prod, Val, Prod`

The `environment` value in your `.tfvars` file does not match the allowed values. Update it:

```hcl
# gmax-nonprod.tfvars
environment = "Non-Prod"

# gmax-val.tfvars
environment = "Val"

# gmax-prod.tfvars
environment = "Prod"
```

---

### Destroy hangs at subnet deletion

This happens when a NAT Gateway or VPC Endpoint is still attached to the subnet. The workflow's **FIX 5** handles this automatically — it deletes NAT Gateways, VPC Endpoints, the Internet Gateway, and releases EIPs before Terraform runs. If running locally, clean up these resources manually in the AWS Console first.

---

### `ConditionalCheckFailedException` or stale lock

```
Error: Error acquiring the state lock
ConditionalCheckFailedException
```

A previous run left a stale DynamoDB lock entry. The workflow's **FIX 4** deletes this automatically before the plan. If running locally:

```bash
terraform force-unlock <LOCK_ID>
```

---

### `Saved plan does not match state lineage`

This error occurs when `terraform plan` and `terraform apply` run in separate workflow runs and the state changes in between. The current single-workflow design prevents this — plan and apply are in the same run, so the state cannot change between them.

---

### `terraform output admin_password` returns empty

The admin password is a sensitive output. Use the `-raw` flag:

```bash
terraform output -raw admin_password
```

---

### ROSA cluster still showing as `Installing` after 45 minutes

This is normal on first provisioning — ROSA can take up to 60 minutes. The GitHub Actions job timeout is set to 90 minutes. Check cluster status:

```bash
rosa describe cluster -c <cluster_name>
rosa logs install -c <cluster_name> --watch
```
