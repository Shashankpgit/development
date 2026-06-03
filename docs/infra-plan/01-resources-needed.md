# Resources Needed — Vault Application Infrastructure

This file lists every GCP resource the vault application needs to run, why it is
needed, and which component of the application depends on it. Read this before
writing any code.

---

## The application we are deploying

```
vault-frontend  (React, served by nginx)
vault-api       (FastAPI, Python)
keycloak        (Identity provider)
kong            (API gateway, JWT validation)
postgres        (Database)
ingress-nginx   (Kubernetes ingress controller)
cert-manager    (Automatic TLS certificates from Let's Encrypt)
```

All of these run as pods inside a GKE cluster. The GKE cluster lives inside a
GCP VPC. Everything below is what that VPC needs to support them.

---

## Resource 1: GCS Bucket (State Storage)

**What it is:** A Google Cloud Storage bucket that stores OpenTofu's state file.

**Why we need it:**
OpenTofu needs to remember what it has already created. It stores this memory in a
file called `terraform.tfstate`. If this file lives on your laptop, your teammate
cannot run OpenTofu — they have no state. If you delete your laptop, all state is
lost and OpenTofu can no longer manage the resources.

The GCS bucket is the central, shared home for state. Everyone who runs OpenTofu
reads and writes to the same bucket.

**Application dependency:** Indirect — nothing in the vault app uses the bucket
directly. It is infrastructure for OpenTofu itself.

**Who creates it:** A bootstrap shell script using `gcloud storage buckets create`.
It cannot be created by OpenTofu (OpenTofu needs the bucket before it can store state).

**Properties:**
- Name: `<project-id>-tofu-state` (globally unique across all of GCP)
- Location: same region as the cluster
- Versioning: enabled (allows rollback if state gets corrupted)
- Uniform bucket-level access: enabled

---

## Resource 2: OpenTofu Service Account + IAM Roles

**What it is:** A GCP service account that OpenTofu uses to authenticate to GCP APIs
when creating resources.

**Why we need it:**
When OpenTofu calls `gcloud compute networks create`, it needs to prove it is
authorised. Instead of using your personal Google account (which changes if you
leave the team), we create a dedicated service account for OpenTofu.

**Who creates it:** The bootstrap shell script.

**IAM roles needed:**

| Role | Why |
|---|---|
| `roles/container.admin` | Create and manage GKE clusters and node pools |
| `roles/compute.admin` | Create VPC, subnet, firewall rules, Cloud NAT, static IP |
| `roles/iam.serviceAccountAdmin` | Create the GKE node service account |
| `roles/iam.serviceAccountUser` | Attach the node SA to the node pool |
| `roles/storage.admin` | Read and write the state bucket |
| `roles/serviceusage.serviceUsageAdmin` | Enable GCP APIs via `google_project_service` |

---

## Resource 3: GCP Project APIs

**What it is:** GCP services that must be activated before their resources can be
created. GCP APIs are enabled per project.

**Why we need it:**
Creating a GKE cluster before enabling `container.googleapis.com` gives you an
opaque `403 Permission Denied` error. The APIs must be the first thing OpenTofu
creates.

**APIs to enable:**

| API | Why |
|---|---|
| `compute.googleapis.com` | VPC, subnet, firewall rules, Cloud Router, Cloud NAT, static IP |
| `container.googleapis.com` | GKE cluster and node pools |
| `iam.googleapis.com` | Service accounts and IAM bindings |
| `cloudresourcemanager.googleapis.com` | Required by many GCP provider operations |
| `servicenetworking.googleapis.com` | VPC-native (alias IP) networking for GKE |

**Application dependency:** Everything. No resource can be created without its API
being enabled.

---

## Resource 4: VPC (Virtual Private Cloud)

**What it is:** An isolated private network inside GCP. All cluster resources live
inside it.

**Why we need it:**
GKE nodes, pods, and services need a network to communicate. The VPC is that network.
Without a VPC, there is nowhere to put the cluster.

We create a custom-mode VPC (`auto_create_subnetworks = false`) so we control every
subnet and IP range explicitly.

**Application dependency:**
Every single resource below lives inside this VPC.

**Properties:**
- Mode: custom (not auto)
- Name: `vault-vpc`

---

## Resource 5: Subnet

**What it is:** A regional slice of the VPC's IP space. GKE nodes get IPs from here.

**Why we need it:**
The VPC is global, but resources must be in a specific region. A subnet assigns an
IP range to `asia-south1`. GKE nodes created in that region get IPs from the subnet.

**We need three IP ranges on this one subnet:**

| Range | CIDR | Who uses it |
|---|---|---|
| Primary | `10.0.0.0/24` | GKE nodes (one IP per node, up to ~251 nodes) |
| Secondary: pods | `10.1.0.0/16` | Kubernetes pods (one IP per pod, ~65,000 pods) |
| Secondary: services | `10.2.0.0/20` | Kubernetes services / ClusterIPs (~4,000 services) |

**Application dependency:**
- GKE cluster references the subnet by name
- GKE cluster references the secondary range names in `ip_allocation_policy`
- Pod-to-pod traffic, node IPs, service IPs all come from this subnet

---

## Resource 6: Cloud Router

**What it is:** A managed BGP speaker. Routes advertise how to reach your VPC from
outside.

**Why we need it:**
Cloud NAT (resource 7) requires a Cloud Router to exist. The router is the control
plane; NAT is the data plane. You cannot create NAT without first creating a router.

**Application dependency:**
Indirect — Cloud Router enables Cloud NAT, which enables image pulls and
cert-manager to work.

**Properties:**
- Region: `asia-south1` (must be same region as the subnet and NAT)
- Network: `vault-vpc`

---

## Resource 7: Cloud NAT

**What it is:** Network Address Translation for outbound traffic. Gives private
GKE nodes internet access without public IPs.

**Why we need it:**
Our GKE nodes are private (no public IPs). Without Cloud NAT, they cannot make
outbound connections. This breaks:

- `ImagePullBackOff` — nodes cannot pull container images from GHCR
- cert-manager fails — cannot reach `acme-v02.api.letsencrypt.org` for Let's Encrypt
- Any pod that calls an external API

**Application dependency:**
- `vault-api` image pull from `ghcr.io/shashankpgit/vault-api`
- `vault-frontend` image pull from `ghcr.io/shashankpgit/vault-frontend`
- cert-manager requesting TLS certificates from Let's Encrypt
- Keycloak, Kong, ingress-nginx image pulls

**Properties:**
- Attached to: `vault-vpc-router` (Cloud Router above)
- NAT IP allocation: `AUTO_ONLY` (GCP manages the external IPs)
- Source ranges: `ALL_SUBNETWORKS_ALL_IP_RANGES` (includes pod IPs)

---

## Resource 8: Reserved Static External IP

**What it is:** A GCP external IP address reserved in your project permanently.

**Why we need it:**
`ingress-nginx` creates a GCP Network Load Balancer when deployed. The LB gets an
external IP. By default, this IP is ephemeral — it changes if the cluster is
destroyed and recreated. That breaks DuckDNS (your DNS record points to the old IP).

With a reserved static IP:
- Set DuckDNS once, after the first `apply`
- Destroy and recreate the cluster as many times as needed
- DuckDNS never needs updating again

**Application dependency:**
- `ingress-nginx` Helm chart configured with `loadBalancerIP: <static-ip>`
- DuckDNS A record points to this IP
- TLS certificate issued for `vaultpraja.duckdns.org` at this IP

**Properties:**
- Type: `EXTERNAL`
- Tier: `PREMIUM` (Google's backbone network, lower latency)
- Region: `asia-south1`

---

## Resource 9: Firewall Rules (4 rules)

**What they are:** Rules at the VPC boundary that decide what traffic is allowed.

GCP default: deny all inbound, allow all outbound. We must explicitly allow what
we need.

### Rule A: allow-inbound-http-https
Allows internet traffic to reach ingress-nginx.

| Field | Value | Why |
|---|---|---|
| Direction | INGRESS | Traffic coming in |
| Source | `0.0.0.0/0` | Anyone on the internet |
| Target | `gke-node` tag | Only GKE nodes |
| Ports | TCP 80, 443 | 80: redirect + Let's Encrypt; 443: HTTPS |

**What breaks without it:** Browser shows "site can't be reached" — packets dropped.

### Rule B: allow-gcp-health-checks
Allows GCP's load balancer to probe ingress-nginx backends.

| Field | Value | Why |
|---|---|---|
| Direction | INGRESS | Probes coming in |
| Source | `35.191.0.0/16`, `130.211.0.0/22` | GCP health checker IP ranges |
| Target | `gke-node` tag | GKE nodes running ingress-nginx |
| Ports | TCP 80, 443, 8443 | Health probe ports |

**What breaks without it:** GCP marks all backends unhealthy → 502 on every request.
Everything looks healthy inside Kubernetes — most confusing failure mode.

### Rule C: allow-internal
Allows pod-to-pod and node-to-node communication inside the cluster.

| Field | Value | Why |
|---|---|---|
| Direction | INGRESS | Traffic within the VPC |
| Source | `10.0.0.0/24` (subnet CIDR) | Traffic from within the subnet |
| Target | `gke-node` tag | GKE nodes |
| Protocol | all | All protocols (TCP, UDP, ICMP) |

**What breaks without it:** Kubernetes internal networking fails. Pods cannot reach
services on other nodes. CoreDNS lookups fail.

### Rule D: allow-egress-https
Documents and protects outbound HTTPS from nodes.

| Field | Value | Why |
|---|---|---|
| Direction | EGRESS | Traffic going out |
| Target | `gke-node` tag | GKE nodes |
| Destination | `0.0.0.0/0` | Any external destination |
| Ports | TCP 443 | HTTPS only |

**What breaks without it:** Nothing currently (GCP allows all egress by default).
This rule documents intent and protects if a deny-all-egress rule is added later.

---

## Resource 10: GKE Node Service Account

**What it is:** A GCP service account that runs on each GKE node (worker VM).
kubelet uses it to write logs, metrics, and pull from Artifact Registry.

**Why we need it:**
The default Compute Engine service account has `Project Editor` rights — far too
broad. We create a dedicated node SA with only the minimum roles kubelet needs.

**IAM roles:**

| Role | Why |
|---|---|
| `roles/logging.logWriter` | kubelet writes container logs to Cloud Logging |
| `roles/monitoring.metricWriter` | kubelet writes CPU/memory metrics |
| `roles/monitoring.viewer` | GKE autoscaler reads monitoring data |
| `roles/stackdriver.resourceMetadata.writer` | Node metadata for dashboards |
| `roles/artifactregistry.reader` | Pull images from Artifact Registry (future use) |

**Note:** GHCR image pulls do NOT use this SA — they go over the internet via Cloud
NAT. This SA is for GCP-internal services only.

---

## Resource 11: GKE Cluster (Control Plane)

**What it is:** The Kubernetes control plane — API server, etcd, scheduler,
controller manager. Managed by Google (you don't see these VMs).

**Why we need it:**
This is the brain of Kubernetes. Without the cluster, there are no nodes, no pods,
no services.

**Key configuration choices:**

| Setting | Value | Why |
|---|---|---|
| `networking_mode` | `VPC_NATIVE` | Pods get alias IPs, routable in VPC |
| `enable_private_nodes` | `true` | Nodes have no public IPs (secure) |
| `enable_private_endpoint` | `false` | API server reachable from internet (kubectl works from laptop) |
| `remove_default_node_pool` | `true` | We manage our own node pool separately |
| `workload_identity_config` | set | Pods authenticate to GCP without JSON keys |
| `deletion_protection` | `false` | Allow `tofu destroy` to delete the cluster |

**Application dependency:**
Every pod, service, and Kubernetes object runs on this cluster.

---

## Resource 12: GKE Node Pool

**What it is:** The worker VMs that run your pods. The control plane schedules pods
onto these nodes.

**Why it is separate from the cluster:**
If the node pool is embedded in the cluster resource, replacing nodes (upgrading
machine type, changing count) would require destroying and recreating the entire
cluster. Keeping them separate means node pool changes are independent of the
control plane.

**Key configuration:**

| Setting | Value | Why |
|---|---|---|
| `machine_type` | `e2-standard-2` | 2 vCPU, 8GB RAM — runs all vault app components |
| `node_count` | `2` | HA: if one node fails, the other keeps serving |
| `service_account` | node SA email | Use our dedicated SA, not the default |
| `tags` | `["gke-node"]` | Must match firewall rule `target_tags` |
| `auto_repair` | `true` | GKE replaces unhealthy nodes automatically |
| `auto_upgrade` | `true` | GKE keeps nodes on latest patch version |
| `enable_secure_boot` | `true` | Nodes verify boot integrity |

**Application dependency:**
Every pod runs on the node pool. No nodes = no pods = nothing works.

---

## Complete resource list in creation order

```
Bootstrap (one-time, via gcloud):
  1.  GCS state bucket
  2.  OpenTofu service account + IAM roles

OpenTofu Module: apis
  3.  5x google_project_service  (GCP APIs)

OpenTofu Module: network
  4.  google_compute_network       (VPC)
  5.  google_compute_subnetwork    (subnet + secondary ranges)
  6.  google_compute_router        (Cloud Router)
  7.  google_compute_router_nat    (Cloud NAT)
  8.  google_compute_address       (static ingress IP)
  9.  google_compute_firewall      (allow-inbound-http-https)
  10. google_compute_firewall      (allow-gcp-health-checks)
  11. google_compute_firewall      (allow-internal)
  12. google_compute_firewall      (allow-egress-https)

OpenTofu Module: gke
  13. google_service_account       (node SA)
  14. google_project_iam_member ×5 (node SA roles)
  15. google_container_cluster     (GKE control plane)
  16. google_container_node_pool   (worker nodes)

Total: 16 GCP resources across 3 OpenTofu modules
```

---

## What this does NOT include

The following exists in `vault-automation/` and is outside this IaC scope:
- Helm chart deployments (ingress-nginx, cert-manager, keycloak, kong, vault-api, vault-frontend)
- Kubernetes namespaces, ConfigMaps, Secrets
- Keycloak realm configuration
- Kong API gateway configuration
- DuckDNS update (manual step after `apply`)
- `kubectl get-credentials` command (manual step after `apply`)
