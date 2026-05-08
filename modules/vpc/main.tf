# ==============================================================================
# modules/vpc/main.tf
#
# Creates the full network layer for the ROSA private cluster:
#
#   VPC 10.0.0.0/16
#   private-a  10.0.0.0/22   (AZ-a)  -- ROSA nodes
#   private-b  10.0.4.0/22   (AZ-b)  -- ROSA nodes
#   public-a   10.0.8.0/24   (AZ-a)  -- NAT Gateway only
#
#   IGW --> NAT GW --> private subnets (outbound only)
#   VPC Endpoints: S3(Gateway) EC2 STS ELB ECR-API ECR-DKR (Interface)
# ==============================================================================

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

# Private Subnet A (AZ-a) -- ROSA masters + workers
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = var.availability_zones[0]

  tags = merge(var.tags, {
    Name                              = var.master_subnet_name
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Private Subnet B (AZ-b) -- additional workers for AZ distribution
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[1]
  availability_zone = var.availability_zones[1]

  tags = merge(var.tags, {
    Name                              = var.worker_subnet_name
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Public Subnet A (AZ-a) -- NAT Gateway only, no cluster workloads
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.availability_zones[0]

  tags = merge(var.tags, {
    Name                     = var.public_subnet_name
    "kubernetes.io/role/elb" = "1"
  })
}

# Internet Gateway -- door between VPC and internet, required for NAT GW
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# Elastic IP for NAT Gateway -- static public IP for outbound traffic
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nat-eip"
  })
}

# NAT Gateway -- gives private nodes outbound access without inbound exposure
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_internet_gateway.this]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nat-gw"
  })
}

# Public route table -- internet-bound traffic via IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# Private route table -- outbound traffic via NAT GW (shared by both private subnets)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-private-rt"
  })
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Security Group for Interface VPC Endpoints -- HTTPS from VPC CIDR only
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.cluster_name}-vpce-"
  description = "Allow HTTPS from VPC CIDR to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpce-sg"
  })
}

# S3 Gateway Endpoint (free) -- ROSA uses S3 for OIDC, ignition files, install logs
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpce-s3"
  })
}

# EC2 Interface Endpoint -- ROSA operators call EC2 API constantly
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpce-ec2"
  })
}

# STS Interface Endpoint -- IRSA credential refresh every hour
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpce-sts"
  })
}

# ELB Interface Endpoint -- ROSA manages internal NLBs via ELB API
resource "aws_vpc_endpoint" "elb" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.elasticloadbalancing"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpce-elb"
  })
}

# ECR API Interface Endpoint -- authentication for Amazon ECR
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpce-ecr-api"
  })
}

# ECR DKR Interface Endpoint -- docker image layer pulls from ECR
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpce-ecr-dkr"
  })
}
