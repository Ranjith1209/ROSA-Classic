variable "cluster_name" {
  type        = string
  description = "Cluster name — used in resource names and tags."
}

variable "aws_region" {
  type        = string
  description = "AWS region — used in VPC endpoint service names."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block. e.g. 10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Exactly 2 AZ names. e.g. [us-east-1a, us-east-1b]"

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones required."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Exactly 2 private subnet CIDRs (one per AZ). ROSA nodes live here."

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly 2 private subnet CIDRs required."
  }
}

variable "public_subnet_cidr" {
  type        = string
  description = "Single public subnet CIDR (AZ-a). NAT Gateway only — no cluster workloads."
}

variable "master_subnet_name" {
  type        = string
  description = "AWS Name tag for the master/private subnet in AZ-a."
}

variable "worker_subnet_name" {
  type        = string
  description = "AWS Name tag for the worker/private subnet in AZ-b."
}

variable "public_subnet_name" {
  type        = string
  description = "AWS Name tag for the public subnet (NAT Gateway)."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources in this module."
  default     = {}
}
