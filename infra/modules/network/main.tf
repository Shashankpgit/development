locals {
  name_prefix = "${var.env_name}-${var.app_name}"
  node_tag    = "${var.env_name}-${var.app_name}-node"
}

resource "google_compute_network" "vpc" {
  name                    = "${local.name_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${local.name_prefix}-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_cidr

  secondary_ip_range {
    range_name    = var.pods_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = var.services_range_name
    ip_cidr_range = var.services_cidr
  }
}

resource "google_compute_router" "router" {
  name    = "${local.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${local.name_prefix}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_address" "ingress_ip" {
  name         = "${local.name_prefix}-ingress-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
}

# ── Rule 1: allow inbound HTTP + HTTPS ────────────────────────────────────────
resource "google_compute_firewall" "allow_inbound_http_https" {
  name      = "${local.name_prefix}-allow-inbound-http-https"
  project   = var.project_id
  network   = google_compute_network.vpc.id
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.node_tag]
}

# ── Rule 2: allow GCP load balancer health check probes ───────────────────────
resource "google_compute_firewall" "allow_gcp_health_checks" {
  name      = "${local.name_prefix}-allow-gcp-health-checks"
  project   = var.project_id
  network   = google_compute_network.vpc.id
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8443"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = [local.node_tag]
}

# ── Rule 3: allow internal cluster traffic ────────────────────────────────────
resource "google_compute_firewall" "allow_internal" {
  name      = "${local.name_prefix}-allow-internal"
  project   = var.project_id
  network   = google_compute_network.vpc.id
  direction = "INGRESS"

  allow {
    protocol = "all"
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = [local.node_tag]
}

# ── Rule 4: allow egress HTTPS ────────────────────────────────────────────────
resource "google_compute_firewall" "allow_egress_https" {
  name      = "${local.name_prefix}-allow-egress-https"
  project   = var.project_id
  network   = google_compute_network.vpc.id
  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = [local.node_tag]
}
