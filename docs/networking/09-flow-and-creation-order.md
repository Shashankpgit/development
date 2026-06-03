# Flow Diagram, Creation Order, and Gotchas

## The complete architecture — read this like a map

```
═══════════════════════════════════════════════════════════════════════════════
                          VAULT STACK — FULL NETWORK FLOW
═══════════════════════════════════════════════════════════════════════════════

  USER'S BROWSER
  (anywhere in the world)
         │
         │  DNS lookup: vaultpraja.duckdns.org
         ▼
  ┌──────────────────┐
  │    DuckDNS DNS   │  resolves to our static IP
  └──────────────────┘
         │  35.200.100.1  (google_compute_address — EXTERNAL, PREMIUM, regional)
         ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║  GCP NETWORK EDGE (Google's global backbone)                                ║
║                                                                              ║
║  ┌────────────────────────────────────────────────────────────────────────┐ ║
║  │  GCP Network Load Balancer (provisioned by ingress-nginx LB Service)  │ ║
║  │                                                                        │ ║
║  │  External IP: 35.200.100.1  ←── google_compute_address.ingress_ip     │ ║
║  │  Protocol: TCP (not HTTP-aware)                                        │ ║
║  │  Health probes from: 35.191.0.0/16, 130.211.0.0/22 ──────────────┐   │ ║
║  └───────────────────────────────────────────────┬────────────────────┘   ║ ║
║                                                   │                    │   ║ ║
╚═══════════════════════════════════════════════════│════════════════════│═══╝ ║
                                                    │                    │     ║
  ┌─────────────────────── Firewall Check ──────────▼────────────────────▼──┐ ║
  │  [1] allow-inbound-http-https: src 0.0.0.0/0 → TCP 80,443 → gke-node   │ ║
  │  [2] allow-gcp-health-checks:  src GCP LB IPs → TCP 80,443,8443        │ ║
  └────────────────────────────────────────────────────────────────────────┘ ║
         │                                                                     ║
╔════════▼════════════════════════════════════════════════════════════════════╗
║  VPC: vault-vpc  (google_compute_network)                                   ║
║  ┌──────────────────────────────────────────────────────────────────────┐   ║
║  │  Subnet: vault-subnet  (google_compute_subnetwork)                    │   ║
║  │  Primary CIDR:   10.0.0.0/24  ← node IPs                            │   ║
║  │  Secondary CIDR: 10.1.0.0/16  ← pod IPs (alias IPs)                 │   ║
║  │  Secondary CIDR: 10.2.0.0/20  ← service ClusterIPs                  │   ║
║  │                                                                        │   ║
║  │  ┌──────────────────┐  ┌──────────────────┐                          │   ║
║  │  │  GKE NODE 1      │  │  GKE NODE 2      │  ... (node pool)         │   ║
║  │  │  IP: 10.0.0.4    │  │  IP: 10.0.0.5    │                          │   ║
║  │  │  Alias: 10.1.0.x │  │  Alias: 10.1.1.x │                          │   ║
║  │  │                  │  │                  │                          │   ║
║  │  │  ┌────────────┐  │  │  ┌────────────┐  │                          │   ║
║  │  │  │ingress-    │  │  │  │ vault-api  │  │                          │   ║
║  │  │  │nginx pod   │  │  │  │ pod        │  │                          │   ║
║  │  │  │10.1.0.5    │  │  │  │ 10.1.1.2   │  │                          │   ║
║  │  │  └─────┬──────┘  │  │  └────────────┘  │                          │   ║
║  │  └────────┼─────────┘  └──────────────────┘                          │   ║
║  │           │                                                            │   ║
║  │  ┌────────▼──────────────────────────────────────────────────────┐    │   ║
║  │  │  Services (ClusterIP virtual IPs)                              │    │   ║
║  │  │  vault-api-svc:    10.2.0.1  → routes to vault-api pods       │    │   ║
║  │  │  keycloak-svc:     10.2.0.2  → routes to keycloak pods        │    │   ║
║  │  │  postgres-svc:     10.2.0.3  → routes to postgres pods        │    │   ║
║  │  └───────────────────────────────────────────────────────────────┘    │   ║
║  │                                                                        │   ║
║  │  ┌─────────────────────── Internal traffic ──────────────────────┐    │   ║
║  │  │  Firewall: allow-internal                                      │    │   ║
║  │  │  src: 10.0.0.0/24 → all protocols → gke-node                  │    │   ║
║  │  └───────────────────────────────────────────────────────────────┘    │   ║
║  └──────────────────────────────────────────────────────────────────────┘   ║
║                                                                              ║
║  ┌──────────────────────────────────────────────────────────────────────┐   ║
║  │  Outbound path (EGRESS from nodes)                                    │   ║
║  │                                                                        │   ║
║  │  GKE Node (10.0.0.4)                                                  │   ║
║  │    │  "pull image from ghcr.io"                                       │   ║
║  │    ▼  [Firewall: allow-egress-https permits TCP 443]                  │   ║
║  │  Cloud Router (google_compute_router)                                  │   ║
║  │    │  BGP control plane — route advertisement                         │   ║
║  │    ▼                                                                   │   ║
║  │  Cloud NAT (google_compute_router_nat)                                 │   ║
║  │    │  src: 10.0.0.4 → translated to → GCP NAT external IP            │   ║
║  │    ▼                                                                   │   ║
║  └───────────────────────────────────────────────────────────────────────┘   ║
╚══════════════════════════════════════════════════════════════════════════════╝
         │
         ▼
    INTERNET
  (ghcr.io, acme-v02.api.letsencrypt.org, etc.)
```

---

## Inbound path: step by step

```
Step  Who does what
────  ─────────────────────────────────────────────────────────────────────
  1   User's browser resolves vaultpraja.duckdns.org → gets 35.200.100.1
  2   Browser sends TCP SYN to 35.200.100.1:443
  3   GCP routes to the Network Load Balancer
  4   GCP LB checks: is a backend healthy? (pings ingress-nginx on port 80)
      → needs allow-gcp-health-checks firewall rule
  5   GCP LB forwards the packet to an ingress-nginx pod on one of the nodes
      → needs allow-inbound-http-https firewall rule
  6   ingress-nginx terminates TLS (decrypts the HTTPS traffic)
  7   ingress-nginx reads the hostname and path
      → Host: vaultpraja.duckdns.org, Path: /api/notes
      → matches Ingress rule: /api/* → vault-api-svc:8000
  8   ingress-nginx forwards to vault-api Service ClusterIP (10.2.0.1:8000)
  9   kube-proxy rewrites dst: 10.2.0.1 → 10.1.1.2 (a vault-api pod)
 10   vault-api pod handles the request
 11   vault-api pod queries postgres-svc (10.2.0.3:5432) → postgres pod
 12   Response flows back: postgres → vault-api → ingress-nginx → NLB → browser
```

---

## Outbound path: step by step

```
Step  Who does what
────  ─────────────────────────────────────────────────────────────────────
  1   kubelet on a node starts and needs to pull vault-api:latest from ghcr.io
  2   kubelet makes TCP connection to ghcr.io:443
  3   Firewall check: allow-egress-https rule → ALLOW TCP 443 outbound
  4   Packet reaches the VPC's default internet gateway
  5   Cloud Router advertises the route (knows how to reach external destinations)
  6   Cloud NAT intercepts the packet
  7   Cloud NAT translates src: 10.0.0.4 → src: <NAT external IP>
  8   Packet reaches ghcr.io
  9   ghcr.io sends image data back to <NAT external IP>
 10   Cloud NAT translates dst: <NAT external IP> → dst: 10.0.0.4
 11   Node receives the image data
```

---

## Resource creation order

This is the sequence you must follow manually (or what Terragrunt enforces
automatically via `dependency {}` blocks):

```
Step  Resource                       Why this order
────  ─────────────────────────────  ────────────────────────────────────────────
  1   Enable GCP APIs                 Everything else needs these APIs enabled.
      (google_project_service)        If APIs are disabled, all other creates fail.

  2   VPC                             Everything else lives inside the VPC.
      (google_compute_network)        Subnet, Router, NAT, Firewall reference it.

  3   Subnet                          The subnet references the VPC.
      (google_compute_subnetwork)     GKE cluster references the subnet.
                                      Secondary ranges must exist before GKE.

  4   Cloud Router                    NAT requires the router to exist.
      (google_compute_router)         Router references the VPC.

  5   Cloud NAT                       References the router.
      (google_compute_router_nat)     Cannot exist without a router.

  6   Static IP reservation           Needs to be reserved BEFORE the GKE cluster
      (google_compute_address)        creates the LoadBalancer Service, or the
                                      ingress-nginx Service cannot claim it.

  7   Firewall rules                  Reference the VPC. Order among themselves
      (google_compute_firewall ×4)    does not matter. Can be created any time
                                      after the VPC exists, but must exist before
                                      traffic is expected.

  8   GKE Node Service Account        Must exist before the cluster is created.
      (google_service_account)        The node pool references the SA email.

  9   IAM roles on the node SA        Must be granted before nodes start making
      (google_project_iam_member ×5)  API calls (Logging, Monitoring).

 10   GKE Cluster (control plane)     References VPC, subnet, and secondary ranges.
      (google_container_cluster)      Requires APIs enabled and subnet ready.

 11   GKE Node Pool                   References the cluster and the node SA.
      (google_container_node_pool)    Cannot be created without the cluster.
```

**Destroy order is exactly reversed (11 → 1).** GKE node pool first, then cluster,
then SA, then firewall rules, then static IP, then NAT, then router, then subnet,
then VPC, then APIs.

Why reversed? Because you cannot delete the VPC while the GKE cluster is using the
subnet. You cannot delete the subnet while the node pool has nodes with IPs from it.

Terragrunt's `dependency {}` blocks enforce this automatically — you never have to
remember the order manually.

---

## Things that will definitely bite you (gotchas)

### Gotcha 1: Missing GCP health check firewall rule → silent 502
If `allow-gcp-health-checks` (ports from 35.191.0.0/16, 130.211.0.0/22) is missing:
- `kubectl get pods` shows ingress-nginx as `Running`
- `kubectl get svc` shows an external IP
- Every request from the browser returns `502 Bad Gateway`
- GKE and Kubernetes look healthy — the problem is invisible from inside the cluster

Fix: add the firewall rule. GCP LB will detect the backends as healthy within ~30 seconds.

### Gotcha 2: Missing Cloud NAT → ImagePullBackOff on every pod
If Cloud NAT is missing:
- New pods fail with `ErrImagePull` then `ImagePullBackOff`
- Error: `failed to pull and unpack image "ghcr.io/...": context deadline exceeded`
- `kubectl exec -it node -- curl https://ghcr.io` times out

Fix: create Cloud Router + Cloud NAT. Pods will succeed on next retry.

### Gotcha 3: Overlapping secondary CIDRs → GKE cluster creation fails
If the pods CIDR or services CIDR overlaps with the primary subnet CIDR:
- GKE cluster creation fails with: "subnet is not configured to support alias IP ranges"
  or "IP range conflicts"

Fix: choose non-overlapping CIDRs before creating the subnet. You cannot change
subnet CIDRs after creation without deleting and recreating.

### Gotcha 4: Ephemeral ingress IP → DuckDNS breaks after cluster recreate
Symptom: app worked yesterday, cluster was recreated, DNS points to old IP.
Fix: reserve a static IP before creating the cluster; assign it in ingress-nginx values.

### Gotcha 5: master_ipv4_cidr_block overlaps with VPC CIDRs
GKE creates a peering with a Google-managed VPC using the CIDR you specify in
`master_ipv4_cidr_block`. If this overlaps with anything in your VPC, cluster
creation fails.

Safe choice: use `172.16.0.0/28` — it's outside all RFC 1918 ranges commonly used
for GKE node/pod/service CIDRs (which are typically in 10.x.x.x).

### Gotcha 6: APIs not enabled → opaque 403 on cluster create
If `container.googleapis.com` is not enabled, creating the GKE cluster returns:
`Error 403: Kubernetes Engine API has not been used in project ... before or it is disabled.`

Fix: enable APIs first (Phase 19.3 in our stack) or the bootstrap script does it
via `gcloud services enable`.

### Gotcha 7: Node tag mismatch → firewall rules don't apply
If `node_config.tags = ["my-nodes"]` but `firewall.target_tags = ["gke-node"]`,
the firewall rules do not apply. Traffic is denied by the implied deny-all-ingress.

Fix: tags must match exactly. We use `"gke-node"` in both the GKE module and the
network module.

---

## Quick-reference: what breaks if X is missing

| Missing resource | What breaks |
|---|---|
| VPC | Nothing can be created — everything references the VPC |
| Subnet | GKE cluster creation fails (no network for nodes) |
| Secondary IP ranges on subnet | GKE VPC-native cluster creation fails |
| Cloud Router | Cloud NAT cannot be created |
| Cloud NAT | ImagePullBackOff, cert-manager stays Pending, all pod HTTP calls timeout |
| allow-inbound-http-https | All external traffic (browser requests) is dropped |
| allow-gcp-health-checks | 502 on all requests (GCP LB marks all backends unhealthy) |
| allow-internal | Kubernetes internal networking breaks (pod-to-service calls fail) |
| Static IP reservation | Ingress IP changes on cluster recreate (DuckDNS breaks) |
| GKE APIs enabled | Cluster creation fails with 403 |
| Node SA | Node pool creation fails (no service account to attach) |
| IAM roles on node SA | Logs and metrics missing from Cloud Monitoring |

---

## Consolidated GCP Exam Tips

### CIDR
- /24 = 256 IPs (251 usable after GCP reserves 5)
- /16 = 65,536 IPs; /20 = 4,096 IPs; /28 = 16 IPs
- Non-overlapping ranges are mandatory for subnets, peered VPCs, and secondary ranges

### VPC
- GCP VPC is global; subnets are regional
- Custom mode: you define subnets explicitly (production choice)
- Auto mode: GCP creates one subnet per region (dev only)

### Subnets & secondary ranges
- VPC-native GKE requires 2 secondary ranges: pods + services
- Alias IPs make pod IPs routable in the VPC without static routes
- Primary CIDR cannot be changed after creation; only expanded

### Cloud Router
- Required as a prerequisite for Cloud NAT
- Regional resource
- Manages BGP for VPN and Interconnect

### Cloud NAT
- Source NAT: translates private → public for outbound connections
- Does NOT allow inbound connections to private nodes
- Both Cloud Router AND Cloud NAT are needed together
- Regional — one per region

### Firewall rules
- Default: deny all inbound, allow all outbound (implied rules at 65534/65535)
- Lower priority number = higher priority (1000 beats 2000)
- Stateful for TCP/UDP — return traffic allowed automatically
- GCP health check ranges: 35.191.0.0/16, 130.211.0.0/22 — memorise these

### Static IP
- Regional for Network LB (ingress-nginx); Global for Global HTTPS LB
- Billed when reserved but unattached
- PREMIUM tier uses Google's backbone; STANDARD uses public internet

### GKE networking
- Three IP spaces: node (primary), pod (secondary), service (ClusterIP)
- LoadBalancer Service → provisions GCP Network LB
- Ingress → routes HTTP/S traffic using hostname/path rules
- Workload Identity → pods get GCP API access via KSA mapping, no JSON keys
