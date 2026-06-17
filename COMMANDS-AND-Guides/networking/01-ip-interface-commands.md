# Networking — Part 01: IP, Interfaces, and Routing Commands

**20-minute read. These are the commands you run first when something can't reach something else.**

---

## The `ip` Command — The Modern Tool

`ifconfig` is old and deprecated. `ip` (from the `iproute2` package) is what every modern Linux system uses. Learn `ip` — not `ifconfig`.

### ip addr — View Network Interfaces

```bash
ip addr show
ip addr          # same thing (shorthand works everywhere in ip)
ip a             # even shorter
```

Sample output explained:
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
    link/loopback 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
    inet6 ::1/128 scope host

2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    link/ether 52:54:00:ab:cd:ef brd ff:ff:ff:ff:ff:ff
#   └── MAC address (Layer 2 hardware address)
    inet 10.0.1.15/24 brd 10.0.1.255 scope global eth0
#        └── IP/subnet  └── broadcast address
    inet6 fe80::5054:ff:feab:cdef/64 scope link
#        └── IPv6 link-local (auto-configured, starts with fe80)

3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
```

```bash
# Show a specific interface
ip addr show eth0

# Show only IPv4 addresses
ip -4 addr

# Show only IPv6 addresses
ip -6 addr
```

### Flags to Know

| Flag | Meaning |
|------|---------|
| `UP` | Interface is administratively up |
| `LOWER_UP` | Physical link is up (cable connected) |
| `NO-CARRIER` | Interface is up but no cable/link |
| `BROADCAST` | Can send to all devices on the segment |
| `MULTICAST` | Supports multicast |

---

### ip link — Manage Interface State

```bash
# Show interfaces (without IP addresses)
ip link show
ip link

# Bring an interface up or down
sudo ip link set eth1 up
sudo ip link set eth1 down

# Set MTU (Maximum Transmission Unit)
# Default is 1500. Kubernetes overlay networks often need lower MTU (e.g., 1450)
sudo ip link set eth0 mtu 1450

# Show interface statistics (packets, errors, drops)
ip -s link show eth0
# RX: bytes packets errors dropped
# TX: bytes packets errors dropped
# Non-zero "dropped" or "errors" = hardware/driver problem
```

---

### ip addr — Add and Remove Addresses

```bash
# Add an IP to an interface
sudo ip addr add 10.0.2.50/24 dev eth0

# Remove an IP
sudo ip addr del 10.0.2.50/24 dev eth0

# Add a temporary IP for testing (gone after reboot)
sudo ip addr add 192.168.100.1/24 dev eth0
```

---

## ip route — Routing Table

```bash
# Show the routing table
ip route show
ip route
ip r     # shortest form

# Example output:
default via 10.0.1.1 dev eth0 proto dhcp metric 100
#└── any destination not matched below → send to 10.0.1.1 (your default gateway)
10.0.1.0/24 dev eth0 proto kernel scope link src 10.0.1.15
#└── 10.0.1.x → send directly via eth0 (same subnet, no gateway needed)
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1
#└── Docker containers → send via docker0 bridge
```

```bash
# Show route for a specific destination
ip route get 8.8.8.8
# 8.8.8.8 via 10.0.1.1 dev eth0 src 10.0.1.15
# Tells you: to reach 8.8.8.8, go via 10.0.1.1, using eth0, with source IP 10.0.1.15

ip route get 172.17.0.5
# 172.17.0.5 dev docker0 src 172.17.0.1
# Direct — no gateway needed (same network)
```

### Add/Delete Routes

```bash
# Add a route: to reach 10.200.0.0/16, go via 10.0.1.254
sudo ip route add 10.200.0.0/16 via 10.0.1.254 dev eth0

# Add a default gateway
sudo ip route add default via 10.0.1.1 dev eth0

# Delete a route
sudo ip route del 10.200.0.0/16

# Delete the default route
sudo ip route del default
```

**Real-world scenario:** Your Kubernetes CNI adds routes for pod subnets on each node:
```
10.244.0.0/24 via 10.0.1.10 dev eth0   ← pods on node1
10.244.1.0/24 via 10.0.1.11 dev eth0   ← pods on node2
10.244.2.0/24 via 10.0.1.12 dev eth0   ← pods on node3
```
If a pod can't reach pods on another node, check these routes exist with `ip route`.

---

## ip neigh — ARP Table (Layer 2 Resolution)

ARP (Address Resolution Protocol) maps IP addresses to MAC addresses within the same subnet.

```bash
# Show the ARP table
ip neigh show
ip neigh
ip n

# Example output:
10.0.1.1 dev eth0 lladdr 52:54:00:12:34:56 REACHABLE
10.0.1.20 dev eth0 lladdr 52:54:00:ab:cd:ef STALE
172.17.0.2 dev docker0 lladdr 02:42:ac:11:00:02 REACHABLE
```

**States:**
- `REACHABLE`: recently verified, communication works
- `STALE`: not recently used, will be re-verified before next use
- `FAILED`: resolution failed — that IP is unreachable on the local network

```bash
# Flush stale entries
sudo ip neigh flush dev eth0

# Add a static ARP entry (useful when you know the MAC and ARP is broken)
sudo ip neigh add 10.0.1.99 lladdr 52:54:00:99:99:99 dev eth0

# Delete an entry
sudo ip neigh del 10.0.1.99 dev eth0
```

---

## Making Changes Permanent

`ip` commands are temporary — they survive until reboot. For permanent changes:

**On Ubuntu/Debian with Netplan (Ubuntu 18.04+):**
```yaml
# /etc/netplan/01-network-config.yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 10.0.1.15/24
      routes:
        - to: default
          via: 10.0.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```
```bash
sudo netplan apply
```

**Check current Netplan config:**
```bash
cat /etc/netplan/*.yaml
sudo netplan try    # apply temporarily (reverts after 2 minutes unless confirmed)
```

---

## Network Namespaces — How Containers Get Isolated Networks

Every container has its own network namespace — a completely separate network stack (interfaces, routes, firewall rules).

```bash
# List network namespaces
ip netns list

# Create a namespace
sudo ip netns add testns

# Run a command inside a namespace
sudo ip netns exec testns ip addr show
# Only sees the loopback interface — completely isolated

# Delete namespace
sudo ip netns del testns
```

**Real-world:** When debugging a container networking issue, you can enter its network namespace:
```bash
# Get the container's PID
CONTAINER_PID=$(docker inspect --format '{{.State.Pid}}' vault-api)

# Enter its network namespace
sudo nsenter -t $CONTAINER_PID -n ip addr show
sudo nsenter -t $CONTAINER_PID -n ss -tlnp
# Now you see the container's interfaces and open ports from inside its namespace
```

---

## Real-World Scenario 1: "My new server can't reach the internet"

```bash
# Step 1: Does it have an IP?
ip addr show eth0
# If no inet line → no IP assigned. DHCP problem or static config missing.

# Step 2: Does it have a default route?
ip route show
# Must have "default via X.X.X.X dev ethX" line
# If missing: sudo ip route add default via 10.0.1.1 dev eth0

# Step 3: Can it reach the gateway?
ping -c 3 10.0.1.1    # gateway IP from the route table
# If fails → Layer 2 problem. Wrong VLAN, bad cable, ARP issue.
# ip neigh show → is the gateway MAC resolved?

# Step 4: Can it reach an external IP? (bypass DNS)
ping -c 3 8.8.8.8
# If ping to gateway works but 8.8.8.8 fails → routing problem at gateway
# or firewall blocking outbound traffic

# Step 5: Is DNS working?
dig @8.8.8.8 google.com
# If this works but "dig google.com" fails → local DNS is broken (/etc/resolv.conf)
```

---

## Real-World Scenario 2: Kubernetes CNI Pod Cannot Reach Another Node

```bash
# Pod on node1 can't reach pod on node2

# Step 1: Check the route exists on node1
ip route show | grep 10.244.2.0
# Expected: 10.244.2.0/24 via 10.0.1.12 dev eth0
# If missing: CNI is not configuring routes. Check CNI pod logs.

# Step 2: Can node1 ping node2?
ping 10.0.1.12
# If fails: basic VM-level connectivity issue (security group, VPC route table)

# Step 3: Is the CNI pod running?
kubectl get pods -n kube-system | grep flannel
kubectl get pods -n kube-system | grep calico

# Step 4: Check if there's IP forwarding enabled (required for K8s networking)
cat /proc/sys/net/ipv4/ip_forward
# Must be 1. If 0: sudo sysctl -w net.ipv4.ip_forward=1

# Step 5: Check iptables rules (CNI adds rules here)
sudo iptables -L -n | head -50
```

---

## Common Misunderstanding: "I brought the interface up with `ip link set up` — it has an IP now"

**The misunderstanding:** "Setting an interface up gives it an IP address."

**The reality:** `ip link set up` only enables the interface — it's the equivalent of plugging in the cable and powering on the NIC. You still need an IP address assigned, either via:

```bash
# DHCP (automatic)
sudo dhclient eth1

# Or static (manual)
sudo ip addr add 10.0.2.50/24 dev eth1
sudo ip route add default via 10.0.2.1 dev eth1
```

An interface being `UP` just means it can potentially carry traffic. Without an IP address assigned, nothing can use it.

→ Continue to: `02-dns-commands.md`
