# infra/modules/gke/main.tf
# Creates: GKE node service account + IAM bindings, GKE cluster (control plane),
# and the node pool (worker nodes).

# ── Node service account ───────────────────────────────────────────────────────
# GKE nodes run as this service account.  The default Compute Engine SA has
# project-editor rights — far too broad.  This dedicated SA gets only the
# minimum roles the GKE node agent (kubelet) actually needs.

resource "google_service_account" "node_sa" {
  account_id   = var.node_sa_name
  display_name = "GKE Node Pool Service Account"
  project      = var.project_id
}

# ── Minimum IAM roles for the node SA ─────────────────────────────────────────
# Each role is a separate resource so adding/removing a role is a targeted
# change in the plan, not a replace of the whole SA.

# kubelet writes container and node logs to Cloud Logging
resource "google_project_iam_member" "node_sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

# kubelet writes CPU/memory/disk metrics to Cloud Monitoring
resource "google_project_iam_member" "node_sa_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

# GKE system components read monitoring data to make autoscaling decisions
resource "google_project_iam_member" "node_sa_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

# Writes node metadata (OS image, machine type) to Cloud Monitoring so dashboards
# can correlate metrics to specific node types
resource "google_project_iam_member" "node_sa_metadata_writer" {
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

# Required if any workload pulls images from Google Artifact Registry.
# Not needed for GHCR (GitHub Container Registry) — that goes over public internet
# via Cloud NAT, no GCP IAM involved.
resource "google_project_iam_member" "node_sa_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

# ── GKE cluster (control plane only) ─────────────────────────────────────────
# This resource creates the GKE control plane.  The default node pool is
# removed immediately because we manage the node pool as a separate resource.
#
# Why separate cluster + node_pool resources?
#   - You can upgrade or replace nodes without changing control-plane config
#   - You can add multiple node pools (e.g. spot + regular) independently
#   - Terraform plan shows cluster and node changes as distinct operations

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region

  # GKE requires initial_node_count when remove_default_node_pool = true.
  # The default pool is deleted immediately after cluster creation; this value
  # is discarded.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_name
  subnetwork = var.subnet_name

  # VPC-native mode: pods and services get IPs from subnet secondary ranges
  # instead of routing through the node's primary IP.
  # Required for: private networking, Network Policy enforcement, and
  # services that need predictable IP ranges.
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private cluster: nodes have no public IPs.
  # enable_private_endpoint = false keeps the Kubernetes API server reachable
  # from your laptop (via its external IP).  Set to true in a zero-trust setup
  # where kubectl runs from a bastion only.
  # master_ipv4_cidr_block is a /28 in a Google-managed VPC that gets peered
  # to this VPC — it must not overlap with any of your CIDR ranges.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Workload Identity: pods authenticate to GCP APIs via Kubernetes service
  # accounts instead of using the node SA credentials or JSON key files.
  # The node SA (defined above) is used by kubelet, not by pods.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Allow 'tofu destroy' to delete this cluster without going to the GCP console
  # to click "disable deletion protection" first.
  deletion_protection = false

  min_master_version = var.k8s_version

  lifecycle {
    # GKE auto-upgrades the control plane to the latest patch version.
    # Without this, every subsequent plan would show:
    #   ~ min_master_version: "1.30.x-gke.y" → "1.30"
    # which is a no-op diff.  Ignoring keeps the plan output clean.
    ignore_changes = [min_master_version]
  }
}

# ── Node pool ──────────────────────────────────────────────────────────────────

resource "google_container_node_pool" "nodes" {
  name       = var.node_pool_name
  project    = var.project_id
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  version = var.k8s_version

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"

    service_account = google_service_account.node_sa.email

    # cloud-platform is required when Workload Identity is enabled.
    # It is a broad OAuth scope, but Workload Identity intercepts GCP API calls
    # from pods and enforces the Kubernetes SA's IAM bindings instead.
    # The broad scope is never directly used by pod workloads.
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    # These tags must match target_tags in the firewall rules defined in the
    # network module.  If the tags differ, the firewall rules do not apply to
    # these nodes and external traffic is dropped.
    tags = [var.node_tag]

    labels = {
      environment = "vault"
      managed-by  = "opentofu"
    }

    # Shielded VMs verify the node boot sequence using a TPM chip.
    # Secure boot prevents unsigned kernel modules from loading.
    # Integrity monitoring alerts if the boot measurements change.
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    # auto_repair: GKE replaces nodes that fail health checks
    auto_repair = true
    # auto_upgrade: GKE keeps nodes on the latest GKE patch for the minor version
    auto_upgrade = true
  }

  lifecycle {
    # GKE auto-upgrades node version similarly to master.
    # Ignore the drift so plan stays clean.
    ignore_changes = [version]
  }
}
