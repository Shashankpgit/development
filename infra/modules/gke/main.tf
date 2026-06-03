locals {
  name_prefix = "${var.env_name}-${var.app_name}"
}

resource "google_service_account" "node_sa" {
  account_id   = "${local.name_prefix}-node-sa"
  display_name = "GKE Node Service Account"
  project      = var.project_id
}

resource "google_container_cluster" "primary" {
  name     = "${local.name_prefix}-cluster"
  project  = var.project_id
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  # Set pd-standard on the temporary default node pool GKE creates during
  # cluster initialisation. Without this it defaults to pd-balanced (SSD)
  # which hits the SSD_TOTAL_GB quota even though the pool is deleted immediately.
  node_config {
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb
  }

  network    = var.vpc_name
  subnetwork = var.subnet_name

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false

  lifecycle {
    ignore_changes = [min_master_version]
  }
}

resource "google_container_node_pool" "nodes" {
  name       = "${local.name_prefix}-node-pool"
  project    = var.project_id
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  node_config {
    machine_type    = var.machine_type
    disk_type       = var.disk_type
    disk_size_gb    = var.disk_size_gb
    service_account = google_service_account.node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = [var.node_tag]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  lifecycle {
    ignore_changes = [version]
  }
}

resource "google_project_iam_member" "node_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}
