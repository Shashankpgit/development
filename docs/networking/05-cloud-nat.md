# Cloud NAT

## The core problem

You created private GKE nodes — they have no public IP. This protects them from
the internet. But it also means they have no way to make outbound connections.

When a node tries to pull a container image from GHCR (`ghcr.io`):

```
Node (private IP: 10.0.0.4)  →  ghcr.io (public IP: 140.82.113.x)
                                   ↑
                        "Where do I send the response?"
                        10.0.0.4 is a private IP — it cannot be
                        reached from the public internet.
                        Response dropped. Connection fails.
```

**Cloud NAT** is the solution.

---

## What NAT means

NAT = Network Address Translation. It translates IP addresses as packets pass
through it. There are two types:

### Source NAT (SNAT) — what Cloud NAT does
Translates the **source** IP of outbound packets from private → public:

```
Before NAT:
  src: 10.0.0.4  →  dst: 140.82.113.x

Cloud NAT translates:
  src: 34.100.10.50 (NAT's external IP)  →  dst: 140.82.113.x

GHCR sees the request as coming from 34.100.10.50. It sends the response there.
Cloud NAT receives the response, translates back to 10.0.0.4, and delivers it to the node.
```

The node never needs a public IP. The outside world sees the NAT's IP.

### Destination NAT (DNAT) — what Cloud NAT does NOT do
Translates the destination IP of inbound packets. Used for port forwarding.
Cloud NAT does not do DNAT — private nodes remain unreachable from the internet.

---

## What breaks without Cloud NAT

This is the most important section. These failures are silent or misleading:

| What fails | Error you see | Why |
|---|---|---|
| Container image pull | `ImagePullBackOff` | Kubelet on node cannot reach `ghcr.io` or `docker.io` |
| cert-manager | `CertificateRequest` stays `Pending` | Cannot reach `acme-v02.api.letsencrypt.org` |
| External API calls from pods | `Connection timeout` | Any `curl` to the internet from inside a pod |
| `apt-get` on nodes | Times out | Nodes cannot reach Debian/Ubuntu package repos |
| Helm chart pulls | `Error: failed to fetch` | Chart repositories are on the internet |

The `ImagePullBackOff` error is the most common first symptom in a new cluster
that is missing Cloud NAT. Beginners often assume the image name is wrong or the
registry credentials are missing, but the actual cause is: the node cannot make
a TCP connection to `ghcr.io` because it has no way out.

---

## How Cloud NAT works internally

```
┌─────────────────────────────────────────────────────┐
│ VPC: vault-vpc                                       │
│                                                      │
│  Node: 10.0.0.4                                      │
│    │                                                  │
│    │ outbound packet to ghcr.io                      │
│    ▼                                                  │
│  Cloud Router (vault-vpc-router)                     │
│    │                                                  │
│    │ route: "0.0.0.0/0 via default internet gateway" │
│    ▼                                                  │
│  Cloud NAT (vault-vpc-nat)                           │
│    │  Translates: src 10.0.0.4 → src 34.100.10.50   │
│    │  Records: (10.0.0.4, port X) ↔ (34.100.10.50, port Y) │
│    │                                                  │
└────┼─────────────────────────────────────────────────┘
     │
     ▼  internet
  ghcr.io (140.82.113.x) ← receives from 34.100.10.50
     │
     │ response
     ▼
  Cloud NAT ← receives at 34.100.10.50:Y
    │  Translates back: dst 34.100.10.50:Y → dst 10.0.0.4:X
    ▼
  Node: 10.0.0.4  ← receives the image data
```

**Connection tracking**: Cloud NAT maintains a table of active connections. It knows
which internal (private) address corresponds to which external (public) port. Without
this table, return traffic cannot be correctly delivered.

---

## NAT IP allocation modes

### AUTO_ONLY (what we use)
GCP automatically provisions and manages the external IPs used by NAT. You don't
reserve any IPs for NAT yourself. GCP adds more IPs automatically as traffic increases.

```hcl
nat_ip_allocate_option = "AUTO_ONLY"
```

### MANUAL_ONLY
You reserve specific external IPs and assign them to NAT. Useful when:
- External services whitelist specific IPs (e.g. a payment gateway allows only your IP)
- You need stable, predictable outbound IPs for compliance/auditing

```hcl
nat_ip_allocate_option = "MANUAL_ONLY"
nat_ips                = [google_compute_address.nat_ip.self_link]
```

---

## Source subnet range options

Controls which subnets and IP ranges get NAT applied:

### ALL_SUBNETWORKS_ALL_IP_RANGES (what we use)
Every IP in every subnet — including pod IPs (alias IPs) and the primary node IPs —
gets NAT applied when making outbound connections.

```hcl
source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
```

### ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES
Only the primary CIDR (node IPs) gets NAT. Pod IPs (alias IPs) do NOT.
This means pods themselves cannot reach the internet directly.
In most setups you want pods to be able to reach external services, so this is
rarely the right choice for GKE.

### LIST_OF_SUBNETWORKS
You specify exactly which subnets and ranges get NAT. Most granular, most work.

---

## Cloud NAT and the egress firewall rule

Cloud NAT requires that the VPC allow egress traffic. GCP's default firewall
allows all egress, so this usually works without extra rules. We add an explicit
egress firewall rule (`allow-egress-https`) for documentation and future-proofing:
if a deny-all-egress rule is ever added, our explicit allow-443 rule survives.

```
Node → Cloud NAT → internet (port 443)
 ↑
 Firewall rule "allow-egress-https" permits this
```

---

## Cloud NAT vs Public Nodes — why not just give nodes public IPs?

| Private nodes + Cloud NAT | Public nodes |
|---|---|
| No public IP on nodes | Public IP on each node |
| Cannot SSH to nodes from internet (secure) | Anyone can attempt SSH to nodes |
| Cloud NAT cost (~$1/month in most regions) | No NAT cost, but bigger attack surface |
| Nodes are not reachable externally | Nodes are externally reachable |
| Industry best practice for GKE | Only suitable for dev/test |

Production Kubernetes: always private nodes + Cloud NAT.

---

## GCP Cloud Exam Tips

- **Cloud NAT requires Cloud Router**. You always create both. Cloud Router is the
  control plane; Cloud NAT is the data plane for outbound translation.

- Cloud NAT is **egress only**. It does NOT allow inbound connections to private VMs.
  For inbound, you use a Load Balancer or Bastion host.

- Cloud NAT is **not a proxy**. Proxies terminate connections (two TCP sessions).
  NAT translates addresses (one TCP session, different addresses). Pods don't need
  to be configured to use Cloud NAT — it's transparent.

- "A private GKE node is getting `ImagePullBackOff`. The image exists in GHCR.
  What is the most likely cause?" → **Cloud NAT is missing or misconfigured.**

- `ALL_SUBNETWORKS_ALL_IP_RANGES` vs `ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES`:
  the first NATs pod IPs too (needed for GKE); the second NATsonly node IPs.

- Cloud NAT is **regional**, not global. One Cloud NAT per region. If you have VMs
  in us-central1 and asia-south1, you need two Cloud NATs (each referencing a
  Cloud Router in its own region).

- AUTO_ONLY NAT IPs are not predictable — they change when GCP scales the NAT pool.
  If an external service needs to whitelist your outbound IP, use MANUAL_ONLY.
