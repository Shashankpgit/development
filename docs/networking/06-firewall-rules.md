# Firewall Rules

## The real-world analogy

Think of firewall rules as security guards posted at every door of your building
(VPC). Before any packet enters or leaves a room (VM/node), the guard checks a list:

1. Is this traffic allowed? (which rules match?)
2. If multiple rules match, which one has higher priority?
3. Based on the winning rule: allow or deny.

Without any rules you create, GCP provides:
- **Default: deny all inbound** (no traffic can enter)
- **Default: allow all outbound** (all traffic can leave)

Every firewall rule you create is either overriding the deny-inbound default or
adding restrictions to the allow-outbound default.

---

## Anatomy of a firewall rule

Every firewall rule has these properties:

```
Name:         vault-vpc-allow-inbound-http-https
Network:      vault-vpc              ← which VPC this rule applies to
Direction:    INGRESS                ← inbound traffic
Priority:     1000                   ← lower number = higher priority
Action:       ALLOW                  ← what to do when this rule matches
Protocol:     tcp
Ports:        80, 443
Source:       0.0.0.0/0             ← for INGRESS: where traffic comes FROM
Target:       tag: gke-node          ← which resources this rule applies TO
```

---

## Direction: INGRESS vs EGRESS

### INGRESS (inbound)
Traffic coming INTO your resources from outside.

```
Internet → firewall rule check → GKE node
```

INGRESS rules control: who can reach your nodes. You specify `source_ranges`
(where traffic is allowed from) and `target_tags` (which resources to allow it into).

### EGRESS (outbound)
Traffic going OUT from your resources.

```
GKE node → firewall rule check → internet / other service
```

EGRESS rules control: where your nodes can send traffic. You specify
`destination_ranges` (where traffic is allowed to go) and `target_tags` (which
resources this applies to).

```
Direction    source/destination field used
─────────────────────────────────────────
INGRESS      source_ranges or source_tags (where traffic comes FROM)
EGRESS       destination_ranges (where traffic goes TO)
```

---

## Priority

When multiple rules match the same traffic, **the rule with the lowest priority
number wins**.

```
Priority  1000  ALLOW tcp:80 from 0.0.0.0/0
Priority  2000  DENY  tcp:80 from 0.0.0.0/0
                ↑ rule 1000 wins — lower number = higher priority
```

GCP's implied rules (the ones you don't see) sit at:
- Priority 65534: `allow-all-egress` (allows all outbound)
- Priority 65535: `deny-all-ingress` (denies all inbound)

Every rule you create at the default priority (1000) overrides both implied rules.

**Practical example**: To block all traffic from a specific IP range:
1. Create a DENY rule at priority 900 for that range
2. Your existing ALLOW rules are at priority 1000
3. 900 < 1000 → the deny rule wins

---

## Targeting: who does the rule apply to?

### Option 1: Apply to all instances in the network
```hcl
# No target_tags, no target_service_accounts
# Rule applies to EVERY VM and node in the VPC
```

Use this for rules that truly apply to everything. Dangerous — it's easy to
accidentally allow too much.

### Option 2: Target by network tag (what we use)

```hcl
target_tags = ["gke-node"]
```

The rule only applies to VMs (or GKE nodes) that have the tag `gke-node`.
Tags are arbitrary strings you assign to VMs. The firewall checks: "does this
VM have the tag? If yes, apply the rule."

In the GKE module:
```hcl
node_config {
  tags = ["gke-node"]    # GKE nodes get this tag
}
```

In the network module:
```hcl
resource "google_compute_firewall" "allow_inbound_http_https" {
  target_tags = ["gke-node"]   # rule applies to nodes with this tag
}
```

**Why tags are better than applying to all instances:**
If you add a Cloud SQL proxy VM or a bastion host to the same VPC later, the
GKE-specific firewall rules don't accidentally apply to those new VMs.

### Option 3: Target by service account
```hcl
target_service_accounts = ["node-sa@project.iam.gserviceaccount.com"]
```

More secure than tags — tags can be set by anyone with VM access, service accounts
are controlled by IAM. Used in high-security environments.

---

## Our four firewall rules explained

### Rule 1: allow-inbound-http-https

```
Direction: INGRESS
Source:    0.0.0.0/0  (anyone on the internet)
Target:    gke-node
Ports:     TCP 80, 443
```

**Why 80 AND 443?**
- Port 443: HTTPS traffic from browsers, API clients
- Port 80: Two reasons:
  1. HTTP → HTTPS redirect (nginx sends `301 Moved Permanently` on port 80)
  2. cert-manager HTTP-01 challenge: Let's Encrypt sends a request to
     `http://vaultpraja.duckdns.org/.well-known/acme-challenge/TOKEN`
     **over plain HTTP (port 80)** to prove you control the domain.
     Without port 80 open, your TLS certificate will never be issued.

**If this rule is missing:**
Browser shows "This site can't be reached" — packets are dropped at the GCP edge.

### Rule 2: allow-gcp-health-checks

```
Direction: INGRESS
Source:    35.191.0.0/16, 130.211.0.0/22
Target:    gke-node
Ports:     TCP 80, 443, 8443
```

**The story of this rule:**
When ingress-nginx creates a GCP LoadBalancer (type: LoadBalancer Service), GCP
provisions a Network Load Balancer (NLB) with health checkers. The NLB sends
HTTP probe requests to each ingress-nginx pod every few seconds to verify it is
alive before routing real traffic there.

These health check probes come from Google's internal IP ranges:
- `35.191.0.0/16` — GCP health checker range 1
- `130.211.0.0/22` — GCP health checker range 2

These IPs are not advertised openly — they appear only in the GCP documentation
on "Load balancing and firewall rules." Many developers forget this rule.

**If this rule is missing:**
The GCP LB marks ALL backends as UNHEALTHY. Every request returns `502 Bad Gateway`.
The ingress-nginx pods show as `Running` in `kubectl get pods`. This is one of the
most confusing failure modes in GKE because everything looks fine from the Kubernetes
perspective, but all external traffic fails.

**Port 8443:**
ingress-nginx registers a `ValidatingWebhookConfiguration` with the Kubernetes API
server. The API server calls back to ingress-nginx on port 8443 to validate ingress
objects. GCP's probe mechanism also checks this port.

### Rule 3: allow-internal

```
Direction: INGRESS
Source:    10.0.0.0/24  (the subnet CIDR)
Target:    gke-node
Protocol:  all
```

Allows all traffic between resources within the subnet. This covers:
- Pod-to-pod communication across nodes
- Kubelet on node A calling the API server (which is a pod on node B)
- kube-proxy traffic
- CoreDNS responding to pod DNS queries
- CNI plugin (Dataplane V2) traffic between nodes

Without this rule, Kubernetes cluster networking breaks entirely. Pods cannot talk
to services because kube-proxy's inter-node forwarding is blocked.

### Rule 4: allow-egress-https

```
Direction: EGRESS
Target:    gke-node
Dest:      0.0.0.0/0
Ports:     TCP 443
```

Documents that nodes make outbound HTTPS calls. GCP's default allows all egress
anyway, so this rule is technically redundant in our current setup. We include it
because:
1. It is self-documenting — anyone reading the firewall rules knows outbound HTTPS
   is expected and intentional
2. If a deny-all-egress rule is added at a lower priority (higher priority number)
   in the future, this rule protects the essential outbound traffic

---

## Priority examples from our setup

```
Our explicit rules:
  Priority 1000:  allow-inbound-http-https   (ALLOW)
  Priority 1000:  allow-gcp-health-checks    (ALLOW)
  Priority 1000:  allow-internal              (ALLOW)
  Priority 1000:  allow-egress-https          (ALLOW)

GCP implied rules (you cannot see or edit these):
  Priority 65534: allow-all-egress            (ALLOW)
  Priority 65535: deny-all-ingress            (DENY)

Evaluation order for inbound traffic to a gke-node:
  1. Check priority 1000 rules first
  2. If traffic matches allow-inbound-http-https → ALLOW
  3. If traffic matches allow-gcp-health-checks  → ALLOW
  4. If traffic matches allow-internal           → ALLOW
  5. If no rule matches → fall through to priority 65535 → DENY
```

---

## Stateful vs stateless

GCP firewall rules are **stateful** for TCP and UDP. This means:
- If an INGRESS rule allows a TCP connection, the response (EGRESS) is automatically
  allowed without a separate EGRESS rule
- You don't need to write both inbound and outbound rules for the same connection

```
Inbound request:  browser → port 443 → ingress-nginx   (matches rule → ALLOWED)
Outbound response: ingress-nginx → port random → browser (automatically allowed)
```

This is why the `allow-egress-https` rule is for outbound connections INITIATED
by the node (e.g., node pulling an image), not for responses to inbound requests.

---

## Firewall logs

You can enable logging on any firewall rule to see which traffic matched it:

```hcl
log_config {
  metadata = "INCLUDE_ALL_METADATA"
}
```

Logs go to Cloud Logging. Useful for debugging unexpected blocks.
We don't enable this by default (cost), but it is a critical debugging tool.

---

## GCP Cloud Exam Tips

- The exam frequently asks about the **GCP health check IP ranges**:
  `35.191.0.0/16` and `130.211.0.0/22`. Memorise these.

- "What is the default inbound firewall rule in a GCP VPC?"
  → **Deny all inbound** at priority 65535. You must explicitly allow what you need.

- "What is the default outbound firewall rule in a GCP VPC?"
  → **Allow all outbound** at priority 65534.

- **Priority: lower number = higher priority.** A rule at priority 500 overrides
  a rule at priority 1000 for the same traffic. This is counterintuitive.

- For the PCNE exam: know that firewall rules are evaluated **per-connection**,
  not per-packet. Once a connection is allowed (stateful match), all subsequent
  packets in that connection are allowed.

- "Tags vs service accounts for firewall targeting?" — Tags are flexible but can be
  set by VM admins. Service accounts require IAM permissions to assign — more secure.

- Implied deny-all-ingress is at priority **65535** (not 65534). Know both implied
  rule priorities.

- Firewall rules can target: **all instances**, **network tags**, or **service
  accounts**. Never IP ranges on the target side — target is always about which
  resources, not which IPs.
