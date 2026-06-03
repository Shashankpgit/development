# Static vs Ephemeral IP Addresses

## The two types of external IPs in GCP

### Ephemeral IP
- Assigned to a resource when it starts
- Released back to GCP's pool when the resource is stopped or deleted
- A new resource (or restarted resource) gets a different IP
- No extra cost

### Static IP
- Reserved by you explicitly
- Stays with you until you release it — even if no resource is using it
- Survives resource deletion and recreation
- **Billed even when not attached to any resource** (~$0.01/hour for a regional IP)

---

## Why our ingress needs a static IP

The `ingress-nginx` Helm chart creates a Kubernetes `Service` of type `LoadBalancer`.
When GKE sees this, it calls the GCP API to provision an external Network Load
Balancer (NLB). The NLB gets an external IP — the address the world uses to reach
your app.

**Without a reserved static IP:**

```
First apply → GKE creates cluster → ingress-nginx gets LB IP: 35.200.100.1
Update DuckDNS → vaultpraja.duckdns.org → 35.200.100.1  ✓ works

You destroy the cluster to save money:
  → GKE deleted → NLB deleted → IP 35.200.100.1 released back to GCP pool

You recreate the cluster next week:
  → GKE created → ingress-nginx gets LB IP: 34.47.200.7  ← different IP!
  → DuckDNS still points to 35.200.100.1 → app unreachable
  → DNS propagation takes up to 48 hours → stuck for 2 days
```

**With a reserved static IP:**

```
First apply → create static IP → get 35.200.100.1 → reserved, never goes away
             → ingress-nginx configured to use 35.200.100.1
Update DuckDNS → vaultpraja.duckdns.org → 35.200.100.1  ✓ works

You destroy the cluster:
  → GKE deleted → NLB deleted → IP 35.200.100.1 returned to... your reservation
  → IP is still yours

You recreate the cluster:
  → ingress-nginx configured to use 35.200.100.1 (same IP)
  → DuckDNS still valid → app immediately reachable
```

---

## How we assign the static IP to ingress-nginx

The OpenTofu network module creates the static IP:

```hcl
resource "google_compute_address" "ingress_ip" {
  name         = "vault-vpc-ingress-ip"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  region       = var.region
}
```

The output makes it available:

```hcl
output "ingress_static_ip" {
  value = google_compute_address.ingress_ip.address
}
```

After `tofu apply`, you pass this IP to the ingress-nginx Helm chart via
`overrides/ingress-nginx.yaml`:

```yaml
controller:
  service:
    loadBalancerIP: "35.200.100.1"    # the value from tofu output
```

When ingress-nginx creates the LoadBalancer Service, GKE tells GCP to assign
that specific reserved IP to the NLB — instead of allocating a random ephemeral one.

---

## Regional vs Global static IPs

### Regional static IP (what we use)
- Tied to a specific region (e.g., `asia-south1`)
- Used with:
  - Network Load Balancers (TCP/UDP)
  - Regional HTTP(S) load balancers
  - Cloud NAT (MANUAL_ONLY mode)
- GKE's ingress-nginx LoadBalancer Service uses a Network LB → regional IP

### Global static IP
- Not tied to any region
- Used with:
  - Global HTTP(S) Load Balancers (GCP's Ingress object, not ingress-nginx)
  - Global SSL proxy
- Cannot be used with a standard Kubernetes LoadBalancer Service

**Common mistake on the exam:** Using a global IP with a Network LB (or vice versa).
GKE ingress-nginx creates a Network LB → you need a **regional** IP.
GKE's built-in Ingress (via `networking.gke.io/ingress.class: "gce"`) creates a
Global HTTP(S) LB → you need a **global** IP.

---

## Network tier: PREMIUM vs STANDARD

### PREMIUM tier
- Uses Google's private global backbone network for routing
- Traffic enters Google's network at the closest point to the user (e.g. a Google
  PoP in Mumbai routes South Asian traffic)
- Better latency, higher reliability
- Higher cost

### STANDARD tier
- Uses public internet routing to the data center region
- Traffic takes the public internet path until it reaches GCP's region
- Lower cost, potentially higher latency

For a production app serving users: **PREMIUM tier**. The latency difference is
significant especially for users far from the region.

```hcl
resource "google_compute_address" "ingress_ip" {
  network_tier = "PREMIUM"   # we always use this for production
}
```

---

## How the static IP flows through our stack

```
infra/modules/network/main.tf
  google_compute_address.ingress_ip → reserves 35.200.100.1

infra/modules/network/outputs.tf
  output "ingress_static_ip" → value = "35.200.100.1"

scripts/vault-infra.sh (outputs command)
  prints: "Ingress IP: 35.200.100.1"
  prints: "Update DuckDNS A record → 35.200.100.1"

[manual step]
  DuckDNS: vaultpraja.duckdns.org → 35.200.100.1

vault-automation/overrides/ingress-nginx.yaml
  controller.service.loadBalancerIP: "35.200.100.1"

[helm upgrade ingress-nginx]
  Kubernetes Service gets loadBalancerIP: 35.200.100.1
  GKE calls GCP API: "assign reserved IP 35.200.100.1 to this NLB"
  GCP: reserved IP found in project → assigned
```

---

## Billing note

Static IPs cost ~$0.01/hour when NOT attached to any resource. When attached, they
are free (the VM or LB cost covers it). If you destroy the cluster but keep the
static IP reservation, you'll pay a small fee until you recreate the cluster.

To avoid charges: run `destroy-backend` only after you've confirmed you won't need
the IP anymore. Or release the reservation manually with `gcloud compute addresses
delete vault-vpc-ingress-ip --region asia-south1`.

---

## GCP Cloud Exam Tips

- "An application's external IP changed after a maintenance window. How do you
  prevent this?" → **Reserve a static external IP** and assign it to the resource.

- Know the difference between **regional** and **global** static IPs. Global is
  for Global HTTPS LB only. Regional is for Network LB (what ingress-nginx uses).

- Static IPs are billed when **reserved but unattached**. Free when in use.
  The exam tests this billing detail.

- "How do you assign a static IP to a GKE LoadBalancer service?"
  → Set `spec.loadBalancerIP` in the Service manifest (or `loadBalancerIP` in
  Helm values). The IP must already be reserved in the same project/region.

- **Premium vs Standard network tier:** Premium uses Google's backbone (lower
  latency); Standard uses public internet to the GCP region edge.

- A static IP that is assigned to a running NLB shows as "IN_USE" in
  `gcloud compute addresses list`. It shows as "RESERVED" when not attached.
