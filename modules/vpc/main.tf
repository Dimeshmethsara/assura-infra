# Wraps the community terraform-aws-modules/vpc/aws module rather than hand-rolling subnets/
# route tables/NAT from scratch — VPC plumbing is well-trodden ground where a maintained,
# widely-used module reduces bug surface with no loss of control over the choices that actually
# matter here (AZ count, NAT strategy, endpoints). Those app-specific security/cost decisions are
# made explicit below rather than left as module defaults.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Only 2 AZs, not the usual 3: this is a scale-to-zero demo cluster, not a resilience-first
  # production system — a third AZ would add subnet/route-table overhead without buying
  # proportionate value at this scale.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  # Single NAT Gateway, not one-per-AZ: the standard HA recommendation is one per AZ, but with
  # only 1-2 nodes total, losing the NAT's AZ takes the whole demo down regardless — the extra
  # ~$33/mo for a second NAT doesn't buy proportionate resilience at this scale. Documented
  # trade-off, not an oversight.
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for the AWS Load Balancer Controller and EKS to auto-discover subnets for
  # public/internal load balancers and node placement.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = var.tags
}

# Free (no hourly charge, no data-processing charge): ECR image pulls go through S3 under the
# hood, so this materially cuts NAT data-processing costs on every pod image pull without adding
# a second NAT or a paid interface endpoint.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  tags = merge(var.tags, { Name = "${var.name_prefix}-s3-endpoint" })
}
