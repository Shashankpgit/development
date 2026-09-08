# ============================================================================
# EKS: control plane, one managed node group, IRSA, and the addons this app
# actually needs. Nothing else.
# ============================================================================

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  cluster_name = "${var.name_prefix}-eks"

  # Fall back to the control plane's subnets when no node-specific ones are
  # given, so the common case needs only one input.
  node_subnet_ids = length(var.node_subnet_ids) > 0 ? var.node_subnet_ids : var.subnet_ids
  # arn:aws:... in commercial regions, arn:aws-cn / arn:aws-us-gov elsewhere.
  # Hardcoding "aws" works until it silently does not.
  arn_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
}

# ----------------------------------------------------------------------------
# IAM: the control plane's own role
#
# EKS is a managed service that acts on your behalf -- creating network
# interfaces, describing subnets. This role is how it gets permission to.
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "${local.arn_prefix}/AmazonEKSClusterPolicy"
}

# ----------------------------------------------------------------------------
# The control plane
# ----------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = true
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  access_config {
    # "API", not the legacy "CONFIG_MAP".
    #
    # The old way was to hand-edit the aws-auth ConfigMap inside the cluster to
    # grant access. It was famous for two failure modes: a YAML typo locked
    # everyone out irrecoverably, and it lived in the cluster rather than in
    # your IaC. Access Entries are a real AWS API, so access is declared here
    # and cannot be lost by editing a ConfigMap.
    authentication_mode = "API"

    # Grants cluster-admin to whichever IAM identity ran `tofu apply`.
    # Without it you create a cluster you cannot talk to -- the single most
    # common "kubectl says forbidden on a brand new cluster" cause.
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = var.cluster_log_types

  tags = merge(var.tags, { Name = local.cluster_name })

  # The role must exist AND have its policy attached before the cluster is
  # created. Tofu infers the role dependency from role_arn but NOT the policy
  # attachment, so cluster creation can race ahead and fail with an
  # authorisation error. This is the classic EKS ordering bug.
  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# ----------------------------------------------------------------------------
# IRSA: let pods assume IAM roles without static credentials
#
# The cluster issues signed JWTs for service accounts. Registering its OIDC
# issuer with IAM lets AWS trust those tokens, so a pod can call AWS APIs by
# presenting its service account token -- no access keys in Secrets, and
# credentials that expire on their own.
#
# Needed here for the EBS CSI driver, which has to call CreateVolume and
# AttachVolume to satisfy the Postgres PVC.
# ----------------------------------------------------------------------------
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer

  # Fixed value for all EKS OIDC providers.
  client_id_list = ["sts.amazonaws.com"]

  # Pins the CA that signs the issuer's certificate, fetched rather than
  # hardcoded -- AWS has rotated this thumbprint before, and a hardcoded one
  # breaks every new cluster on the day it changes.
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = var.tags
}

# ----------------------------------------------------------------------------
# IAM: the worker nodes' role
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${local.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  # All three are required, and each fails differently if missing:
  #   WorkerNodePolicy  -> the node never joins; it shows up nowhere
  #   CNI_Policy        -> the node joins but pods get no IP (ContainerCreating forever)
  #   ECR ReadOnly      -> images fail to pull. Needed even though our images
  #                        are on Docker Hub, because the EKS addons themselves
  #                        (coredns, kube-proxy, CNI) come from ECR.
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.node.name
  policy_arn = "${local.arn_prefix}/${each.value}"
}

# ----------------------------------------------------------------------------
# Managed node group
#
# "Managed" means AWS owns the AMI, the bootstrap and the drain-on-replace
# behaviour. The alternative (self-managed ASGs) means writing userdata and
# handling node lifecycle yourself, for no benefit at this scale.
# ----------------------------------------------------------------------------
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name_prefix}-ng"
  node_role_arn   = aws_iam_role.node.arn

  # Node group subnets, NOT the control plane's. Pin to one AZ for a
  # single-node cluster -- see node_subnet_ids in variables.tf.
  subnet_ids = local.node_subnet_ids

  instance_types = [var.node_instance_type]
  capacity_type  = var.node_capacity_type
  disk_size      = var.node_disk_size_gb

  scaling_config {
    desired_size = var.node_count_desired
    min_size     = var.node_count_min
    max_size     = var.node_count_max
  }

  update_config {
    # Replace at most one node at a time during a version upgrade, so the
    # cluster keeps capacity while rolling.
    max_unavailable = 1
  }

  tags = var.tags

  lifecycle {
    # The cluster autoscaler (or a human) changes desired_size at runtime.
    # Without this, the next `tofu apply` would helpfully scale you back to
    # the value in code -- fighting the autoscaler and possibly evicting pods.
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ----------------------------------------------------------------------------
# IRSA role for the EBS CSI driver
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "ebs_csi_assume" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    # This condition is the whole security model of IRSA: the role may only be
    # assumed by a token whose subject is EXACTLY this service account in this
    # namespace. Loosen it to a wildcard and any pod in the cluster can take
    # the role.
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name               = "${local.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "${local.arn_prefix}/service-role/AmazonEBSCSIDriverPolicy"
}

# ----------------------------------------------------------------------------
# Addons
#
# These are cluster components AWS installs and upgrades for you. Declaring
# them here (rather than applying manifests) means their versions are part of
# the same plan as everything else.
# ----------------------------------------------------------------------------
resource "aws_eks_addon" "core" {
  # vpc-cni gives pods VPC IPs; kube-proxy programs Service routing. Both must
  # exist before any pod can be reached, including coredns.
  for_each = toset(["vpc-cni", "kube-proxy"])

  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.value

  # OVERWRITE: EKS pre-installs default versions of these. Without it, the
  # first apply fails with "addon already exists" -- a confusing error on a
  # cluster you just created.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  # coredns runs as ordinary pods, so it needs a node to run ON. Applied
  # before the node group exists, its pods sit Pending and the addon reports
  # DEGRADED. vpc-cni and kube-proxy do not need this -- they are DaemonSets
  # that install onto nodes as they appear.
  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name = aws_eks_cluster.this.name
  addon_name   = "aws-ebs-csi-driver"

  # Wires the IRSA role above onto the addon's service account. This is the
  # line that lets the driver actually call CreateVolume.
  service_account_role_arn = aws_iam_role.ebs_csi[0].arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [aws_eks_node_group.this]
}

# ----------------------------------------------------------------------------
# NOTE: the gp3 StorageClass is deliberately NOT created here.
#
# It is a Kubernetes object, so it would need the `kubernetes` provider -- and
# that provider needs the cluster's endpoint and CA to configure itself. In the
# SAME apply that creates the cluster, those values do not exist at plan time,
# so Tofu either errors out or (worse) plans against a stale endpoint after any
# cluster replacement. Mixing cloud resources and in-cluster objects in one
# state is a well-known way to end up with an apply you cannot run twice.
#
# So it lives in dev/gp3-sc.yaml and is applied by provision.sh with kubectl,
# after the cluster is up. See that file for why WaitForFirstConsumer matters.
# ----------------------------------------------------------------------------
