# Networking — Part 00: The Mental Model Every DevOps Engineer Needs

**20-minute read. No commands — pure concepts. Do this once and the rest becomes obvious.**

---

## Why Networking Matters for DevOps

You deployed your app. The container is running. But the service is unreachable. Is it:
- The app not listening on the right port?
- A firewall blocking the traffic?
- DNS resolving to the wrong IP?
- The wrong network interface?
- A routing issue?
- A TLS certificate problem?

Without the mental model, you run random commands hoping one tells you something. With the model, you know exactly where to look.

---

## The Practical OSI Layers (Ignore Layers 5 and 6)

```
Layer 7 — Application    HTTP, HTTPS, DNS, SSH, gRPC, SMTP
Layer 4 — Transport      TCP (reliable, ordered), UDP (fast, lossy)
Layer 3 — Network        IP addresses, routing between networks
Layer 2 — Data Link      MAC addresses, switches (within same network)
Layer 1 — Physical       Cables, WiFi signals, fiber
```

When debugging, you go **bottom-up**:
1. Is there physical connectivity? (Can I ping?)
2. Is there an IP route? (Can I reach the network?)
3. Is the TCP port open? (Is the app listening?)
4. Is the application responding? (Is it returning the right HTTP status?)

---

## IP Addresses and Subnets — The Actual Explanation

An IP address has two parts: **network** + **host**.

The subnet mask tells you where the split is.

```
IP:      192.168.1.42
Mask:    255.255.255.0  (/24)

Network part: 192.168.1    (first 24 bits — /24)
Host part:    .42          (last 8 bits — can be 1-254)

All devices with 192.168.1.x are on the same network.
Traffic to 192.168.1.x: goes directly to that device (no router needed).
Traffic to anything else: goes to the default gateway (router).
```

### CIDR Notation — The Modern Way

`/24` means the first 24 bits are the network. The remaining bits are hosts.

| CIDR | Hosts | Example |
|------|-------|---------|
| /32 | 1 (specific host) | 10.0.0.5/32 — exactly this IP |
| /30 | 2 usable | Point-to-point links |
| /29 | 6 usable | Small subnet |
| /28 | 14 usable | Small team |
| /24 | 254 usable | 192.168.1.0/24 — typical LAN |
| /16 | 65,534 usable | 10.0.0.0/16 — typical VPC |
| /8 | 16M usable | 10.0.0.0/8 — large private range |

### Private Address Ranges (Never Routed on the Public Internet)

```
10.0.0.0/8        (10.x.x.x)           — your internal network, VPCs
172.16.0.0/12     (172.16.x.x to 172.31.x.x) — Docker default bridges
192.168.0.0/16    (192.168.x.x)        — home networks, office LANs
127.0.0.0/8       (127.x.x.x)          — loopback (127.0.0.1 = localhost)
```

---

## Ports — What They Actually Are

A port is just a number (0-65535) that identifies which process on a machine should handle incoming traffic.

```
IP address    = which machine
Port          = which process on that machine

192.168.1.42:80   → nginx on that machine (HTTP)
192.168.1.42:443  → nginx on that machine (HTTPS)
192.168.1.42:5432 → PostgreSQL on that machine
192.168.1.42:22   → SSH daemon on that machine
```

Well-known ports (0-1023) require root to bind. Ephemeral ports (32768-60999) are assigned by the kernel for outgoing connections.

```
Common ports to memorize:
22    SSH
53    DNS (UDP and TCP)
80    HTTP
443   HTTPS
3306  MySQL
5432  PostgreSQL
6379  Redis
8080  Common dev/proxy HTTP
9090  Prometheus
3100  Loki
3000  Grafana
```

---

## TCP vs UDP — When Each Is Used

**TCP (Transmission Control Protocol)**
- Connection-oriented: 3-way handshake before data flows (SYN → SYN-ACK → ACK)
- Reliable: every packet acknowledged; retransmitted if lost
- Ordered: packets arrive in order
- Use for: HTTP, HTTPS, SSH, databases — anything where every byte matters

```
Client:  SYN  →
Server:       ← SYN-ACK
Client:  ACK  →
         (connection established, data can flow)
Client:  FIN  →              (closing)
Server:       ← FIN-ACK
```

**UDP (User Datagram Protocol)**
- Connectionless: just send, no handshake
- Unreliable: packets can be lost, duplicated, reordered
- Fast: no overhead
- Use for: DNS (fast lookup), video streaming, gaming, VoIP — where speed > reliability

**Why DevOps engineers need to know this:**
- TCP connection refused = app not listening, or firewall rejecting
- TCP connection timeout = firewall dropping silently (not rejecting)
- DNS issues = UDP port 53 blocked
- `tcpdump` shows you both — you need to know what you're looking at

---

## The Journey of a Request: From Browser to App

When a user hits `https://vault.example.com/api/users`:

```
1. DNS Resolution
   Browser: "What's the IP for vault.example.com?"
   DNS server: "It's 34.100.200.50"

2. TCP Connection (Layer 4)
   Browser → 34.100.200.50:443  SYN
   Server  ←                    SYN-ACK
   Browser → 34.100.200.50:443  ACK
   (TCP connection established)

3. TLS Handshake (Layer 7, before HTTP)
   Browser: "I speak TLS 1.3, here are the cipher suites I support"
   Server:  "Here's my certificate. Let's use AES-256-GCM."
   (encrypted channel established)

4. HTTP Request (over encrypted TCP)
   Browser: GET /api/users HTTP/1.1
            Host: vault.example.com
            Authorization: Bearer eyJhb...

5. App Processing
   Nginx receives → forwards to app on localhost:3000
   App queries postgres → returns user list

6. HTTP Response
   HTTP/1.1 200 OK
   Content-Type: application/json
   {"users": [...]}
```

At every step, something can fail. Knowing this path lets you know exactly where to look.

---

## Network Interfaces — What They Are

A network interface is the connection point between your machine and a network. Each one has its own IP address.

```bash
ip addr show
# Output on a typical Linux server:

1: lo: <LOOPBACK,UP>
    inet 127.0.0.1/8       ← loopback: always here, talks to yourself
2: eth0: <BROADCAST,UP>
    inet 192.168.1.42/24   ← your main NIC, talks to the LAN
3: docker0: <BROADCAST>
    inet 172.17.0.1/16     ← Docker bridge: talks to containers
4: veth123abc: <BROADCAST>
    (no IP)                ← virtual interface for a specific container
```

On a cloud VM you might see `ens3`, `eno1`, `eth0` — just the name of the physical/virtual NIC.

In Kubernetes, you'll also see tunnel interfaces like `flannel.1`, `cni0`, `tunl0` — these are for the overlay network.

---

## Routing — How Traffic Finds Its Way

The routing table tells your machine: "to reach network X, send traffic via gateway Y through interface Z."

```
$ ip route show
default via 192.168.1.1 dev eth0     ← anything else: send to your gateway (router)
172.17.0.0/16 dev docker0            ← Docker containers: send directly via docker0
192.168.1.0/24 dev eth0              ← local LAN: send directly via eth0
10.0.0.0/8 via 10.10.0.1 dev eth1   ← corporate VPN: route via VPN gateway
```

When you add a Kubernetes cluster, CNI plugins add routes like:
```
10.244.0.0/24 via 192.168.1.43 dev eth0   ← pods on node-2: route through node-2
10.244.1.0/24 via 192.168.1.44 dev eth0   ← pods on node-3: route through node-3
```

---

## The Three Types of Connection Failure

You'll encounter exactly three network failure modes:

**1. Connection Refused (ECONNREFUSED)**
```
curl: (7) Failed to connect to host port 80: Connection refused
```
The network path is fine. The machine received your SYN but sent back RST (reset). The port is not open. Either the app isn't running, or it's not listening on that port/interface.

**2. Connection Timeout (ETIMEDOUT)**
```
curl: (28) Failed to connect to host port 80: Connection timed out
```
Your SYN packet was sent but no response. The firewall is dropping packets silently (not rejecting them). The machine might not exist, or a firewall between you and it is dropping traffic without sending back an RST.

**3. Connection Reset Mid-Session**
```
curl: (56) Recv failure: Connection reset by peer
```
The connection was established but the remote end closed it abruptly. The app crashed, hit a timeout, or a load balancer removed the backend.

Understanding these three tells you immediately whether to look at the app, the firewall, or both.

---

## DevOps-Specific Networking Concepts

### Load Balancer
Distributes incoming connections across multiple backend servers. The client connects to the LB's VIP (Virtual IP); the LB picks a backend and forwards the connection.

- **Layer 4 LB**: forwards based on TCP/UDP. Fast, can't read HTTP headers.
- **Layer 7 LB**: understands HTTP. Can route based on URL path, Host header, cookies.

### NAT (Network Address Translation)
Rewrites source/destination IPs as packets pass through. Your home router does NAT: all your devices share one public IP; the router remembers which internal device initiated each connection and routes replies back correctly.

In Kubernetes: kube-proxy uses NAT to rewrite the Service ClusterIP to a pod IP. In cloud: NAT Gateway lets private subnet instances reach the internet without getting a public IP.

### VXLAN / Overlay Networks
When containers or pods are on different physical hosts, they need to communicate. Overlay networks (used by Flannel, Calico, Docker Swarm) wrap packets inside UDP packets and send them between hosts. The container thinks it's talking to a flat network; the host unwraps and rewraps packets.

---

## Common Misunderstanding: "localhost and 0.0.0.0 are the same"

**The misunderstanding:** "My app is listening on localhost:3000 — it should be accessible from other machines."

**The reality:**
- `127.0.0.1` (localhost): loopback interface only. ONLY processes on the same machine can connect. Completely inaccessible from outside.
- `0.0.0.0`: bind to ALL network interfaces. Any interface (eth0, docker0, etc.) can receive connections. Accessible from the outside.

```
app listening on 127.0.0.1:3000  → only curl localhost:3000 from the same machine works
app listening on 0.0.0.0:3000    → curl from any machine on the network works
app listening on 192.168.1.42:3000 → only connections to this specific IP work
```

When a containerized app is unreachable from outside the container, check: is it listening on `127.0.0.1` (inside the container) instead of `0.0.0.0`?

```bash
# Check what address an app is listening on:
ss -tlnp | grep 3000
# LISTEN 0 128 127.0.0.1:3000  → only localhost → problem
# LISTEN 0 128 0.0.0.0:3000    → all interfaces → correct
```

→ Continue to: `01-ip-interface-commands.md`
