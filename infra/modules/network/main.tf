# infra/modules/network/main.tf
# Creates: VPC, subnet (with pod/service secondary ranges for GKE VPC-native),
# Cloud Router, Cloud NAT, reserved static external IP, and 4 firewall rules.

# ── VPC ────────────────────────────────────────────────────────────────────────
# auto_create_subnetworks = false means we control the subnets explicitly.
# GCP default VPCs auto-create one subnet per region; we don't want that.

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
}

# ── Subnet ─────────────────────────────────────────────────────────────────────
# GKE in VPC-native mode requires two secondary IP ranges on the subnet:
#   pods     — each pod gets an IP from this range (not from the node's primary IP)
#   services — each ClusterIP service gets an IP from this range
#
# Without these secondary ranges, GKE cluster creation fails with:
#   "Subnetwork is not configured to use VPC alias IP ranges"

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
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

# ── Cloud Router ───────────────────────────────────────────────────────────────
# Cloud Router is a BGP speaker managed by GCP.  Cloud NAT uses it to
# advertise route changes.  You configure it by name; GCP manages the rest.

resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}

# ── Cloud NAT ─────────────────────────────────────────────────────────────────
# Translates private node IPs to a GCP-managed external IP for outbound traffic.
#
# Without Cloud NAT, private GKE nodes CANNOT:
#   - Pull container images from GHCR (github.com packages)
#   - Reach acme-v02.api.letsencrypt.org (cert-manager HTTP-01 challenge fails)
#   - Make any external API call from inside a pod
#
# nat_ip_allocate_option = AUTO_ONLY  — GCP manages the external IPs for NAT.
#   No reserved IPs needed for NAT (the ingress static IP is separate).
#
# source_subnetwork_ip_ranges_to_nat = ALL_SUBNETWORKS_ALL_IP_RANGES
#   All subnets in this VPC (including pod secondary range IPs) get NAT.

resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ── Reserved static external IP ───────────────────────────────────────────────
# ingress-nginx's LoadBalancer service is assigned this IP via:
#   controller.service.loadBalancerIP in the ingress-nginx Helm values.
#
# Without a reservation the LoadBalancer IP is ephemeral — it changes every
# time the GKE cluster is destroyed and recreated.  With a reservation:
#   - Set DuckDNS once after the first apply
#   - Destroy and recreate the cluster as many times as needed
#   - DNS never needs updating again

resource "google_compute_address" "ingress_ip" {
  name         = "${var.vpc_name}-ingress-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

# ── Firewall: allow inbound HTTP + HTTPS ───────────────────────────────────────
# Permits internet traffic to reach ingress-nginx on ports 80 and 443.
#
# Port 80 is required for two reasons:
#   1. HTTP → HTTPS redirect (nginx-ingress handles this)
#   2. cert-manager HTTP-01 ACME challenge — Let's Encrypt sends a request to
#      http://<domain>/.well-known/acme-challenge/<token>.  Without port 80
#      open, certificate issuance fails and HTTPS is never available.
#
# target_tags = [var.node_tag] targets only nodes with that tag.
# GKE nodes get this tag via the node pool's node_config.tags.

resource "google_compute_firewall" "allow_inbound_http_https" {
  name    = "${var.vpc_name}-allow-inbound-http-https"
  project = var.project_id
  network = google_compute_network.vpc.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.node_tag]
}

# ── Firewall: allow GCP load balancer health check probes ─────────────────────
# GCP's external load balancer sends health probes from these two IP ranges to
# verify that ingress-nginx backends are healthy before routing traffic to them.
#
# Without this rule:
#   - GCP marks ALL backends as UNHEALTHY
#   - Every external request returns 502 Bad Gateway
#   - The ingress-nginx pods are running fine; the problem is invisible in K8s
#
# These ranges are GCP-internal.  35.191.0.0/16 and 130.211.0.0/22 are not
# publicly documented on the main health-check page; they appear only in the
# "Using health checks with firewall rules" guide.  It is one of the most
# common causes of silent 502s in new GKE deployments.
#
# Port 8443 is included for the ValidatingWebhookConfiguration that
# ingress-nginx registers — GCP occasionally probes that port too.

resource "google_compute_firewall" "allow_gcp_health_checks" {
  name    = "${var.vpc_name}-allow-gcp-health-checks"
  project = var.project_id
  network = google_compute_network.vpc.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8443"]
  }

  source_ranges = [
    "35.191.0.0/16",   # GCP health checker range 1
    "130.211.0.0/22",  # GCP health checker range 2
  ]
  target_tags = [var.node_tag]
}

# ── Firewall: allow internal cluster traffic ──────────────────────────────────
# Permits pod-to-pod, node-to-node, and kubelet communications within the subnet.
#
# Covers:
#   - Pods on different nodes calling each other
#   - kube-proxy forwarding service traffic across nodes
#   - kubelet → API server health checks
#   - CNI plugin inter-node route traffic

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.vpc.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "all"
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = [var.node_tag]
}

# ── Firewall: allow egress HTTPS ──────────────────────────────────────────────
# GCP's default-allow-egress rule already permits all outbound traffic, so this
# rule is technically redundant.  It is included explicitly because:
#   1. It self-documents that outbound HTTPS is intentional
#   2. If a stricter deny-all-egress rule is ever added, this rule survives
#   3. Audit logs reference named rules; "allow-egress-https" is clearer than
#      "default-allow-egress"

resource "google_compute_firewall" "allow_egress_https" {
  name    = "${var.vpc_name}-allow-egress-https"
  project = var.project_id
  network = google_compute_network.vpc.id

  direction = "EGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = [var.node_tag]
}
