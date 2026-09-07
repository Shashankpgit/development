# ============================================================================
# Network: one VPC, public subnets only, an internet gateway.
#
# WHY NO PRIVATE SUBNETS AND NO NAT GATEWAY
#
# The textbook layout puts worker nodes in private subnets and gives them
# outbound internet through a NAT Gateway. That is the right call for
# production, and it costs about $32/month per NAT Gateway plus data
# processing charges -- billed hourly whether or not anything uses it.
#
# For a learning cluster that is the single largest avoidable line item, so
# this module does not create one. Nodes sit in PUBLIC subnets with public IPs
# and reach the internet directly through the Internet Gateway, which is free.
#
# What that trades away, stated plainly:
#   - Worker nodes have public IP addresses. Their security group still allows
#     no inbound traffic from the internet, so they are not reachable, but they
#     are addressable -- a weaker position than being unroutable.
#   - This is NOT how you would run a production cluster.
#
# To move to the production layout later: add private subnets, one NAT Gateway
# per AZ, and point the node group at the private subnet ids. The EKS module
# takes subnet ids as an input precisely so that change touches nothing else.
# ============================================================================

locals {
  # Derive AZ names from the region: "ap-south-1" + "a" -> "ap-south-1a".
  # Using suffixes rather than full names keeps global-values.yaml portable
  # between regions.
  azs = [for s in var.az_suffixes : "${var.aws_region}${s}"]
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Both are REQUIRED by EKS. Without DNS hostnames and DNS support, in-cluster
  # DNS resolution fails in ways that look like random networking flakiness
  # rather than a missing VPC flag.
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "public" {
  # One subnet per AZ. for_each keyed by AZ NAME, not by list index: with
  # count, removing the first AZ would renumber the rest and Tofu would plan to
  # destroy and recreate every subnet after it. A map key is stable.
  for_each = { for az in local.azs : az => az }

  vpc_id = aws_vpc.this.id

  # Carve /20s out of the /16. cidrsubnet(cidr, newbits, netnum):
  #   newbits 4 -> /16 + 4 = /20 (4091 usable addresses each)
  #   netnum   -> which block, by position in the AZ list
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, index(local.azs, each.value))
  availability_zone = each.value

  # Nodes need public IPs to reach the internet without a NAT Gateway.
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${each.value}"

    # This tag is not decoration. The AWS Load Balancer Controller DISCOVERS
    # which subnets to place an internet-facing load balancer in by looking for
    # it. Without the tag, creating an Ingress fails with "could not find any
    # subnets" and nothing explains why.
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  # The default route to the internet. This single entry is what replaces a NAT
  # Gateway: traffic leaves via the (free) Internet Gateway instead of a
  # (billed hourly) managed NAT.
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
