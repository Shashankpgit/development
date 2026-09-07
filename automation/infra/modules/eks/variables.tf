variable "name_prefix" {
  description = "Prefix for every resource name, e.g. \"shop-dev\"."
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the cluster in (from the network module)."
  type        = string
}

variable "subnet_ids" {
  description = <<-EOT
    Subnets for the control plane AND the node group. Must span >= 2 AZs.

    These are public subnets in this setup -- see the note in modules/network
    about why there is no NAT Gateway. Swapping in private subnet ids is the
    only change needed to move nodes off public IPs.
  EOT
  type        = list(string)
}

variable "cluster_version" {
  description = <<-EOT
    Kubernetes minor version for the control plane, e.g. "1.33".

    Pin it. Leaving it unset means a new cluster silently lands on whatever is
    current, and your local kubectl may be too old to talk to it. AWS supports
    each version for a limited window and then force-upgrades it, so this is a
    value to review, not set once and forget.
  EOT
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = <<-EOT
    EC2 instance type for the workers.

    Watch the POD LIMIT, not just CPU and memory. With the AWS VPC CNI every
    pod gets a real VPC IP from the node's network interfaces, so the max pods
    per node is fixed by the instance type:
      t3.small  ->  11 pods
      t3.medium ->  17 pods
      t3.large  ->  35 pods
    kube-system alone uses 4-5 (aws-node, kube-proxy, coredns, ebs-csi). This
    app needs 5 more (2 api + 2 web + 1 postgres). t3.small technically fits
    across 2 nodes; t3.medium leaves room to debug without playing Tetris.
  EOT
  type        = string
  default     = "t3.medium"
}

variable "node_capacity_type" {
  description = <<-EOT
    "SPOT" or "ON_DEMAND".

    SPOT is ~70% cheaper and can be reclaimed with a 2-minute warning. For a
    learning cluster that is a good trade, and it is genuinely useful: it
    forces you to notice whether your PodDisruptionBudget and rolling updates
    actually work. Use ON_DEMAND if a node vanishing mid-demo would annoy you.
  EOT
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["SPOT", "ON_DEMAND"], var.node_capacity_type)
    error_message = "node_capacity_type must be SPOT or ON_DEMAND."
  }
}

variable "node_count_desired" {
  description = "Starting number of nodes."
  type        = number
  default     = 2
}

variable "node_count_min" {
  description = "Minimum nodes. 1 keeps the cluster alive at the lowest cost."
  type        = number
  default     = 1
}

variable "node_count_max" {
  description = "Maximum nodes. Caps the bill if something scales unexpectedly."
  type        = number
  default     = 3
}

variable "node_disk_size_gb" {
  description = <<-EOT
    Root EBS volume per node, in GB.

    This is NOT where the Postgres data lives -- that gets its own EBS volume
    via the PVC and the EBS CSI driver. This disk holds the OS, kubelet and
    container images, and 20GB is comfortable for that.
  EOT
  type        = number
  default     = 20
}

variable "endpoint_public_access" {
  description = <<-EOT
    Expose the Kubernetes API to the internet.

    true is required here: with no VPN and no bastion, a private-only endpoint
    means kubectl cannot reach the cluster from your laptop at all. Restrict
    WHO can reach it with public_access_cidrs below.
  EOT
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = <<-EOT
    Which source CIDRs may reach the Kubernetes API.

    0.0.0.0/0 means the whole internet can attempt to authenticate. That is
    not as bad as it sounds -- it is still IAM-authenticated, not open -- but
    narrowing it to your own IP ("x.x.x.x/32") is free and strictly better.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_ebs_csi_driver" {
  description = <<-EOT
    Install the EBS CSI driver addon.

    REQUIRED for this app. The in-cluster Postgres uses a PersistentVolumeClaim,
    and since Kubernetes 1.23 the in-tree EBS provisioner is gone -- without
    this addon the PVC sits Pending forever with no obvious cause, and the
    Postgres pod never starts.
  EOT
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = <<-EOT
    Control plane logs to send to CloudWatch.

    Empty by default ON PURPOSE. Control plane logging is billed by ingestion
    and storage, and "audit" in particular is high volume -- easily a few
    dollars a month on an idle cluster. Enable ["api", "audit"] while
    debugging an authorisation problem, then turn it back off.
  EOT
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
