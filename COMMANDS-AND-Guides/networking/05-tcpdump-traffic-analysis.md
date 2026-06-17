# Networking — Part 05: tcpdump — See Every Packet

**20-minute read. When all higher-level tools fail, tcpdump shows you the raw truth of what's on the wire.**

---

## Why tcpdump?

When `curl` fails and you don't know why, you have two choices:
1. Guess and check config files
2. Watch the actual packets and see what's happening

`tcpdump` is option 2. It captures packets on a network interface and shows you exactly what's being sent and received — no abstractions, no interpretations.

**When to use tcpdump:**
- You think traffic is being dropped by a firewall (see SYN with no SYN-ACK)
- You want to verify traffic is arriving at all
- You need to see what data the app is actually sending
- You're debugging a protocol issue (DNS, HTTP, custom protocol)
- A service says it's responding but the client isn't getting anything

---

## Basic Syntax

```bash
sudo tcpdump [options] [filter expression]

# Capture on a specific interface
sudo tcpdump -i eth0

# Capture on any interface
sudo tcpdump -i any

# Most useful default flags
sudo tcpdump -i eth0 -nn -v
# -n  = don't resolve IP addresses to hostnames (faster)
# -nn = don't resolve ports either (show port numbers)
# -v  = verbose (show more packet details)
```

---

## Essential Filters

The filter expression is the most important part. Without it, you get overwhelmed with every packet.

### Filter by Host

```bash
# All traffic to/from a host
sudo tcpdump -i eth0 -nn host 10.0.1.50

# Only traffic FROM a host
sudo tcpdump -i eth0 -nn src host 10.0.1.50

# Only traffic TO a host
sudo tcpdump -i eth0 -nn dst host 10.0.1.50
```

### Filter by Port

```bash
# All traffic on port 80
sudo tcpdump -i eth0 -nn port 80

# Port 443 (HTTPS)
sudo tcpdump -i eth0 -nn port 443

# Multiple ports (OR)
sudo tcpdump -i eth0 -nn port 80 or port 443

# Port range
sudo tcpdump -i eth0 -nn portrange 8000-9000
```

### Filter by Protocol

```bash
# TCP only
sudo tcpdump -i eth0 -nn tcp

# UDP only
sudo tcpdump -i eth0 -nn udp

# ICMP (ping packets)
sudo tcpdump -i eth0 -nn icmp

# DNS (port 53, UDP + TCP)
sudo tcpdump -i eth0 -nn port 53
```

### Combine Filters

```bash
# Traffic between two hosts on port 80
sudo tcpdump -i eth0 -nn host 10.0.1.10 and host 10.0.1.20 and port 80

# All traffic from host on port 443 or 80
sudo tcpdump -i eth0 -nn src host 10.0.1.50 and \( port 80 or port 443 \)

# Exclude noise (SSH so you don't capture your own SSH session)
sudo tcpdump -i eth0 -nn not port 22

# Exclude multiple ports
sudo tcpdump -i eth0 -nn not port 22 and not port 9090
```

---

## Seeing Packet Content

```bash
# Show packet content as ASCII text
sudo tcpdump -i eth0 -nn -A port 80

# Show as hex + ASCII
sudo tcpdump -i eth0 -nn -X port 80

# Show as hex only
sudo tcpdump -i eth0 -nn -x port 80
```

**Important:** For HTTPS (port 443), the content is encrypted — you'll see hex garbage, not readable HTTP. You need to decrypt TLS to see the actual HTTP content (covered at the end of this file).

---

## Save and Read Captures (pcap files)

```bash
# Save to file (for later analysis, or to open in Wireshark)
sudo tcpdump -i eth0 -nn -w capture.pcap port 80

# Save with rotation (1 file per 100MB, keep 10 files)
sudo tcpdump -i eth0 -nn -w capture_%Y%m%d_%H%M%S.pcap \
  -C 100 -W 10 port 80

# Read a saved capture file
tcpdump -r capture.pcap
tcpdump -r capture.pcap -nn port 80     # filter while reading
tcpdump -r capture.pcap -A              # show ASCII content

# Limit capture to N packets then stop
sudo tcpdump -i eth0 -nn -c 1000 port 80
```

---

## Reading tcpdump Output

```
12:30:45.123456 IP 10.0.1.15.52341 > 10.0.1.50.80: Flags [S], seq 1234567890, length 0
```

- `12:30:45.123456` — timestamp (microsecond precision)
- `IP` — Layer 3 protocol
- `10.0.1.15.52341` — source IP.port
- `10.0.1.50.80` — destination IP.port
- `Flags [S]` — TCP flags
- `seq 1234567890` — sequence number
- `length 0` — payload length

### TCP Flags

| Flag | Symbol | Meaning |
|------|--------|---------|
| SYN | S | Start connection |
| SYN-ACK | S. | Connection accepted |
| ACK | . | Acknowledgment |
| FIN | F | Graceful close |
| RST | R | Abort connection (refused or killed) |
| PSH | P | Push data to application now |
| URG | U | Urgent data |

### Reading a TCP Handshake

```
# Normal connection (3-way handshake):
12:30:45.001 client > server: Flags [S]      ← SYN: client wants to connect
12:30:45.002 server > client: Flags [S.]     ← SYN-ACK: server accepts
12:30:45.003 client > server: Flags [.]      ← ACK: client confirms

# Data exchange:
12:30:45.010 client > server: Flags [P.], length 78  ← data (HTTP request)
12:30:45.020 server > client: Flags [P.], length 452 ← data (HTTP response)
12:30:45.021 client > server: Flags [.]      ← ACK

# Graceful close:
12:30:45.030 server > client: Flags [F.]     ← FIN: server initiates close
12:30:45.031 client > server: Flags [.]      ← ACK
12:30:45.032 client > server: Flags [F.]     ← client also FIN
12:30:45.033 server > client: Flags [.]      ← ACK: both sides closed
```

### The Three Failure Patterns in tcpdump

**Pattern 1: Connection Refused (RST immediately)**
```
client > server: Flags [S]      ← SYN sent
server > client: Flags [R.]     ← RST immediately ← port is not open!
```
Something IS running there (the machine exists, the network is fine), but nothing is listening on that port.

**Pattern 2: Firewall Drop (timeout)**
```
client > server: Flags [S]      ← SYN sent
(nothing)                       ← no response at all
client > server: Flags [S]      ← retransmit after 1s
(nothing)                       ← still nothing
client > server: Flags [S]      ← retransmit after 3s
(nothing)                       ← still nothing
(client gives up → "Connection timed out")
```
The firewall is dropping packets without responding. The SYN reaches the machine (or doesn't!) but no RST comes back.

**Pattern 3: SYN-ACK Never Arrives (one-sided)**
```
client > server: Flags [S]      ← SYN sent (captured on CLIENT)
(nothing back on client)        ← client never sees SYN-ACK

# On server:
client > server: Flags [S]      ← server DOES see the SYN
server > client: Flags [S.]     ← server sends SYN-ACK
(but client never sees it)      ← routing asymmetry! SYN-ACK takes different path
```
Traffic goes one way but the return path is broken. Common in multi-NIC setups or after route table changes.

---

## DevOps-Specific Capture Recipes

```bash
# Watch DNS queries (what is my app looking up?)
sudo tcpdump -i eth0 -nn -s0 udp port 53

# Watch HTTP traffic (show the actual URLs)
sudo tcpdump -i eth0 -nn -A tcp port 80 | grep -E "GET|POST|Host:|HTTP/"

# Watch database connections
sudo tcpdump -i eth0 -nn tcp port 5432

# Watch all Kubernetes API server traffic
sudo tcpdump -i any -nn port 6443

# Watch container-to-container traffic on docker bridge
sudo tcpdump -i docker0 -nn -A

# Watch Kubernetes pod traffic (on the CNI interface)
sudo tcpdump -i cni0 -nn

# Capture then analyze with strings
sudo tcpdump -i eth0 -nn -s0 -w /tmp/cap.pcap port 80
strings /tmp/cap.pcap | grep -E "GET|POST|HTTP"
```

---

## Real-World Scenario: "SYN is sent but never gets a SYN-ACK"

```bash
# App can't connect to postgres on another server. nc -zv times out.

# Terminal 1: capture on the SOURCE machine
sudo tcpdump -i eth0 -nn host 10.0.1.50 and port 5432

# Terminal 2: try to connect
nc -zv 10.0.1.50 5432

# Expected if firewall drops:
# 10:00:01 client > 10.0.1.50.5432: Flags [S]   (SYN sent)
# (no response — SYN-ACK never arrives)

# Terminal 1: now capture on the DESTINATION machine  
sudo tcpdump -i eth0 -nn host 10.0.1.15 and port 5432
# Do we even SEE the SYN arriving?

# Case A: SYN never arrives at destination
# → Firewall/security group on the network is dropping it before it reaches the VM

# Case B: SYN arrives, SYN-ACK sent, but never gets back to source
# → Return path is broken (routing issue)
# server: 10:00:01 10.0.1.15.52341 > 10.0.1.50.5432: Flags [S]   (SYN arrived)
#         10:00:01 10.0.1.50.5432 > 10.0.1.15.52341: Flags [S.]  (SYN-ACK sent)
# client: (SYN-ACK never seen here)
# → Check route table on server: ip route get 10.0.1.15
```

---

## Wireshark — The GUI Alternative

For complex captures, open `pcap` files in Wireshark (GUI):

```bash
# Capture and transfer to your laptop
sudo tcpdump -i eth0 -nn -w /tmp/capture.pcap
scp user@server:/tmp/capture.pcap ./
# Open in Wireshark — better filtering, stream following, protocol analysis
```

Useful Wireshark filters:
```
# Follow a single TCP connection:
tcp.stream eq 5

# Show HTTP requests only:
http.request

# Find specific URL:
http.request.uri contains "api/users"

# Find slow HTTP responses (> 1 second):
http.time > 1

# Find TCP RST:
tcp.flags.reset == 1

# Find retransmissions:
tcp.analysis.retransmission
```

---

## Common Misunderstanding: "tcpdump shows all traffic on my network"

**The misunderstanding:** "I can run tcpdump on any machine and see what all machines on my network are sending."

**The reality:** tcpdump shows only traffic that passes through the interface on YOUR machine:
- Traffic TO or FROM your machine (always visible)
- Traffic passing THROUGH your machine (if your machine is a router/bridge)
- Other machines' traffic to each other: NOT visible on a modern switched network

Switches send each packet only to the destination port. Traffic between VM1 and VM3 doesn't pass through VM2 — VM2 can't see it with tcpdump.

Exceptions:
- **On a hub** (rare/old): all traffic is broadcast
- **Port mirroring/SPAN**: a switch can be configured to mirror all traffic to a specific port
- **Docker bridge**: the bridge interface sees all container traffic (run tcpdump on `docker0`)
- **Kubernetes CNI interface** (`cni0`): sees all pod traffic on that node

→ Continue to: `06-firewall-iptables-ufw.md`
