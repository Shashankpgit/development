# GKE Networking — How Everything Comes Together

## Three layers, three IP spaces

When you run GKE on top of the VPC we built, you get three distinct layers, each
with its own IP space:

```
Layer 3: SERVICES  (ClusterIP)     → 10.2.0.0/20   (Kubernetes virtual IPs)
Layer 2: PODS                      → 10.1.0.0/16   (real GCP IPs, routable in VPC)
Layer 1: NODES (VMs)               → 10.0.0.0/24   (real GCP IPs, routable in VPC)
```

A browser request to `https://vaultpraja.duckdns.org` traverses all three layers
from bottom to top (network layer → node → pod → service) and then back:

```
Browser → GCP LB (static IP) → Node (10.0.0.4) → Pod (10.1.0.5) → Service (10.2.0.1)
          ← response flows back the same path
```

---

## Layer 1: Nodes

GKE nodes are GCE VMs. Each node gets:
- **Primary IP**: from the subnet CIDR (`10.0.0.0/24`). This is the node's identity
  in the VPC. Other VPC resources see this IP when the node makes connections.
- **Alias IP range**: a /24 block from the pods secondary range (`10.1.x.0/24`).
  All pods on this node get IPs from this alias block.

```
Node 1:
  Primary IP: 10.0.0.4
  Alias range: 10.1.0.0/24  (pods get IPs 10.1.0.1–10.1.0.254 on this node)

Node 2:
  Primary IP: 10.0.0.5
  Alias range: 10.1.1.0/24  (pods get IPs 10.1.1.1–10.1.1.254 on this node)
```

GCP routing table automatically knows: "packets to 10.1.0.x → go to Node 1 (10.0.0.4)".
No manual routes. No NAT. Pods are first-class VPC citizens.

---

## Layer 2: Pods

Every pod gets an IP from the pods secondary range. This IP is real — any resource
in the VPC can reach a pod directly.

```
Pod: vault-api-7d5b9c-xyz
  IP: 10.1.0.5
  Running on Node 1 (10.0.0.4)

Pod: keycloak-6f8a2b-abc
  IP: 10.1.1.8
  Running on Node 2 (10.0.0.5)

Vault-api pod → curl http://10.1.1.8:8080 → keycloak pod
Works directly — no NAT, no kube-proxy for pod-to-pod traffic
```

Pod IPs are ephemeral — when a pod restarts, it gets a new IP. This is why services
exist.

---

## Layer 3: Services (ClusterIP)

A Kubernetes **Service** is a stable virtual IP that proxies to a set of pods.
The stable IP is called a **ClusterIP**.

```
Service: keycloak-svc
  ClusterIP: 10.2.0.2   (stable — never changes even when pods restart)
  Selects pods with label: app=keycloak

Pod: vault-api → curl http://keycloak-svc:80 → resolved to 10.2.0.2
  kube-proxy intercepts → picks a keycloak pod → forwards to 10.1.1.8:8080
```

Services are virtual — there is no real network interface at `10.2.0.2`. `kube-proxy`
(or Dataplane V2) rewrites destination IPs in the kernel (using iptables or eBPF).

---

## How external traffic reaches a pod: the full path

We have three components involved:
1. **GCP Network Load Balancer** — provisioned by GKE when you create a `LoadBalancer` Service
2. **ingress-nginx** — the Kubernetes ingress controller that routes HTTP/S based on hostname/path
3. **Backend Service** (ClusterIP) — the internal service for each app (vault-api, keycloak)

```
BROWSER
  │
  │ https://vaultpraja.duckdns.org/api/notes
  ▼
DUCKDNS DNS
  │ resolves → 35.200.100.1 (our static IP)
  ▼
GCP NETWORK LOAD BALANCER
  │ IP: 35.200.100.1 (our reserved static external IP)
  │ Protocol: TCP (not HTTP-aware — just forwards packets)
  │ Health checks: probes ingress-nginx pods on port 80
  │
  │ [GCP health check firewall rule needed here]
  │
  ▼
INGRESS-NGINX POD (10.1.0.5, on Node 1: 10.0.0.4)
  │ Receives raw TCP packets, terminates TLS (HTTPS → HTTP internally)
  │ Reads: Host: vaultpraja.duckdns.org, Path: /api/notes
  │ Matches Ingress rule: /api/* → vault-api-svc:8000
  ▼
VAULT-API SERVICE (ClusterIP: 10.2.0.1)
  │ kube-proxy selects a vault-api pod
  ▼
VAULT-API POD (10.1.1.2, on Node 2: 10.0.0.5)
  │ FastAPI handles the request
  │ Queries Postgres (via postgres-svc ClusterIP)
  ▼
RESPONSE flows back the same path
```

---

## Private cluster: control plane access

Our cluster uses `enable_private_nodes = true` (nodes have no public IP) and
`enable_private_endpoint = false` (the control plane API server has a public endpoint).

```
Your laptop  ──── HTTPS ────→  GKE control plane API (public endpoint)
                               │
                    Google-managed VPC (peered to vault-vpc)
                    Control plane CIDR: 172.16.0.0/28
                               │
                               └── communicates with nodes via private IPs
                                   (nodes use 10.0.0.x, accessible via VPC peering)
```

`kubectl get pods` from your laptop: goes to the public endpoint → GKE control plane
→ reads from etcd → returns response.

The control plane talks to nodes via VPC peering (the `172.16.0.0/28` range you
defined in `master_ipv4_cidr_block`). This peering is created automatically by GKE.

---

## Workload Identity

Without Workload Identity, pods use the node's service account to authenticate to
GCP APIs. That means every pod has the same permissions as the node — too broad.

With Workload Identity, each pod uses its own Kubernetes Service Account (KSA),
mapped to a GCP Service Account (GSA):

```
Pod: cert-manager
  KSA: cert-manager/cert-manager
  Mapped to: cert-manager-sa@project.iam.gserviceaccount.com
  IAM: roles/dns.admin  ← ONLY cert-manager can modify DNS

Pod: vault-api
  KSA: default/default
  No GSA mapping → no GCP API access

Node SA: vault-gke-node-sa
  IAM: logging.logWriter, monitoring.metricWriter
  Used by: kubelet on the node (not by pods)
```

When a pod makes a call to a GCP API, the metadata server on the node intercepts
it and exchanges the KSA token for a short-lived GSA token. No JSON key files.

---

## NodePort vs LoadBalancer vs Ingress — the three ways to expose a service

| Method | What it does | When to use |
|---|---|---|
| ClusterIP | Service only reachable inside cluster | Default — for internal services |
| NodePort | Opens a port (30000–32767) on every node | Dev/testing only |
| LoadBalancer | Creates a GCP LB with external IP | One app, one IP per service |
| Ingress | Routes HTTP/S to multiple services via one LB | Multiple services, one IP |

In our stack: ingress-nginx is a `LoadBalancer` Service (gets the static IP).
Every other service (vault-api, keycloak, postgres) is `ClusterIP` (no external access).
Ingress rules route external traffic to the right service based on path.

---

## GCP Cloud Exam Tips

- "A pod's IP changed after a restart. How do services handle this?"
  → Services use **label selectors**, not pod IPs. kube-proxy updates its forwarding
  table automatically when pods are replaced.

- "What is the difference between a NodePort and a LoadBalancer service?"
  → NodePort opens a port on every node's external IP. LoadBalancer provisions a
  GCP NLB with a dedicated external IP. LoadBalancer is NodePort + GCP NLB.

- GKE private cluster has two endpoint modes:
  - `enable_private_endpoint = false` → control plane reachable from internet (default)
  - `enable_private_endpoint = true` → control plane only reachable from inside VPC
    (requires bastion or Corporate IP in master_authorized_networks)

- "VPC-native clusters vs routes-based clusters:" VPC-native uses alias IPs (pod IPs
  are first-class VPC citizens, routable directly). Routes-based uses VPC routes (one
  route per node, hits route limits at scale).

- Workload Identity is the recommended way to give pods GCP API access. No JSON keys
  needed. Bound to a Kubernetes Service Account + GCP Service Account mapping.

- **GKE autopilot** manages nodes automatically — you only define pods, Google
  manages the node pool. **Standard mode** (what we use) gives you full control over
  nodes, machine types, and node pool configuration.
