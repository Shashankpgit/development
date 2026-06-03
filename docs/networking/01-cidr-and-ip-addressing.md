# CIDR and IP Addressing

## What is an IP address?

Every device on a network — a laptop, a server, a pod inside Kubernetes — gets a
number called an IP address. This number is how packets know where to go.

An IPv4 address is a 32-bit number. Humans read it as four groups of 0–255 separated
by dots:

```
10.0.0.5
│  │ │ └── 4th octet (0–255)
│  │ └──── 3rd octet (0–255)
│  └────── 2nd octet (0–255)
└────────── 1st octet (0–255)
```

In binary, `10.0.0.5` is `00001010.00000000.00000000.00000101`.
You don't need to memorise binary for day-to-day work, but understanding that IPs
are just numbers helps explain how ranges work.

---

## Public vs private IP addresses

The internet assigns IPs to devices that need to be reached globally. But not every
device needs a public address — your GKE nodes, for instance, should NOT be
reachable from the internet directly.

**Private IP ranges (RFC 1918)** — reserved for internal use. Routers on the public
internet will never forward packets to these addresses:

| Range | CIDR notation | How many addresses |
|---|---|---|
| 10.0.0.0 – 10.255.255.255 | `10.0.0.0/8` | 16,777,216 |
| 172.16.0.0 – 172.31.255.255 | `172.16.0.0/12` | 1,048,576 |
| 192.168.0.0 – 192.168.255.255 | `192.168.0.0/16` | 65,536 |

In our stack: all node IPs, pod IPs, and service IPs come from the `10.x.x.x` range.
They are private — only accessible inside the VPC.

**Public IPs** appear on the internet. GCP assigns them to load balancers, Cloud NAT
gateways, and resources you explicitly expose. Our ingress static IP is public.

---

## What is CIDR notation?

CIDR stands for Classless Inter-Domain Routing. It is a compact way to write a
range of IP addresses:

```
10.0.0.0/24
│       └── the "prefix length" — how many bits are fixed
└────────── the starting address
```

The prefix length tells you how many bits from the left are fixed (the "network" part)
and how many bits are free to vary (the "host" part):

```
10.0.0.0/24

Fixed bits (network):   24 bits = 10.0.0   (you cannot change these)
Free bits (host):        8 bits = .0 to .255 (these can vary)

Range: 10.0.0.0 → 10.0.0.255  =  256 addresses
```

### The formula

```
Total addresses = 2^(32 - prefix_length)

/8  → 2^24 = 16,777,216 addresses
/16 → 2^16 =     65,536 addresses
/20 → 2^12 =      4,096 addresses
/24 → 2^8  =        256 addresses
/28 → 2^4  =         16 addresses
/32 → 2^0  =          1 address  (a single IP)
```

### Reading CIDR blocks you see in the wild

| CIDR | Range | Count | Typical use |
|---|---|---|---|
| `10.0.0.0/8` | 10.0.0.0 → 10.255.255.255 | 16M | Entire private space |
| `10.0.0.0/16` | 10.0.0.0 → 10.0.255.255 | 65,536 | Large VPC |
| `10.0.0.0/24` | 10.0.0.0 → 10.0.0.255 | 256 | Node subnet |
| `10.1.0.0/16` | 10.1.0.0 → 10.1.255.255 | 65,536 | Pod range |
| `10.2.0.0/20` | 10.2.0.0 → 10.2.15.255 | 4,096 | Service range |
| `172.16.0.0/28` | 172.16.0.0 → 172.16.0.15 | 16 | GKE control plane peering |
| `35.191.0.0/16` | 35.191.0.0 → 35.191.255.255 | 65,536 | GCP health checker |

---

## Why ranges must not overlap

If two subnets share IPs, the network doesn't know which subnet a packet belongs to.

```
WRONG — overlapping ranges:
  Subnet A: 10.0.0.0/24   covers 10.0.0.0 → 10.0.0.255
  Subnet B: 10.0.0.0/16   covers 10.0.0.0 → 10.0.255.255
  Problem: 10.0.0.5 belongs to both — the router is confused

CORRECT — non-overlapping:
  Nodes:    10.0.0.0/24   (256 IPs)
  Pods:     10.1.0.0/16   (65,536 IPs)
  Services: 10.2.0.0/20   (4,096 IPs)
  Each range is distinct — no ambiguity
```

In our `infra.env`:
```bash
SUBNET_CIDR="10.0.0.0/24"   # 256 node IPs
PODS_CIDR="10.1.0.0/16"      # 65,536 pod IPs
SERVICES_CIDR="10.2.0.0/20"  # 4,096 service IPs
```

These three ranges do not overlap. This is intentional.

---

## GCP reserves IPs inside every subnet

When GCP creates a subnet with CIDR `10.0.0.0/24` (256 addresses), it reserves
the first 4 and the last 1:

| Reserved address | Purpose |
|---|---|
| 10.0.0.0 | Network address (identifies the subnet itself) |
| 10.0.0.1 | Default gateway (packets leaving the subnet go here) |
| 10.0.0.2 | Google DNS |
| 10.0.0.3 | Reserved for future GCP use |
| 10.0.0.255 | Broadcast address |

So a /24 gives you 256 − 5 = **251 usable addresses**, not 256.

---

## Choosing the right CIDR size

### For the node subnet (`/24`)
A /24 gives 251 usable IPs. If your cluster will never exceed ~200 nodes,
a /24 is fine. More nodes? Use /23 (512) or /22 (1024).

### For pods (`/16`)
Each GKE node gets a /24 block of pod IPs (256 pod IPs per node).
A /16 pods range supports up to 256 nodes (256 × 256 = 65,536 pod IPs).
If you need more, use /15 or /14.

### For services (`/20`)
Services are rare compared to pods. 4,096 services is enough for most clusters.

### The golden rule
**Bigger is not always better.** Large CIDR blocks are wasteful when they overlap
with routes you need for VPN, peering, or on-premises connectivity. Plan before you
pick.

---

## How CIDR relates to what you see in the Terraform code

```hcl
# modules/network/main.tf

resource "google_compute_subnetwork" "subnet" {
  ip_cidr_range = var.subnet_cidr       # "10.0.0.0/24" — node IPs

  secondary_ip_range {
    ip_cidr_range = var.pods_cidr       # "10.1.0.0/16" — pod IPs
  }

  secondary_ip_range {
    ip_cidr_range = var.services_cidr   # "10.2.0.0/20" — service IPs
  }
}
```

Three distinct non-overlapping ranges, one per purpose.

---

## GCP Cloud Exam Tips

**ACE / PCNE exam questions on this topic:**

- "How many usable IP addresses are in a /28 subnet?"
  Answer: 2^4 = 16 total, 16 − 5 (GCP reserved) = **11 usable**.

- "Which CIDR block is reserved for private use and cannot be routed on the internet?"
  Answer: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 (RFC 1918).

- "A VPC subnet has CIDR 10.0.1.0/24. What is the default gateway IP?"
  Answer: **10.0.1.1** (always the second IP in the subnet, reserved by GCP).

- "How do you prevent CIDR overlap when connecting two VPCs via VPC peering?"
  Answer: Plan non-overlapping CIDRs before creating either VPC — you cannot change
  a subnet's CIDR after creation.

- Know the difference between /8, /16, /24, /32 by heart. The exam gives you
  scenarios and asks which CIDR is most appropriate.

- `0.0.0.0/0` means "any IP address" (all 4 billion). You see this in firewall rules
  that allow traffic from anywhere on the internet.
