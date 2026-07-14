# Operating Systems — 06: Networking From the OS

> **Last updated:** July 6, 2026
> **Network interfaces, routing, DNS resolution, and open ports — the OS-level view of networking.**

---

## Network Interfaces

A **network interface** is the OS's representation of a network connection — physical (eth0, ens5) or virtual (lo, docker0, veth...).

```bash
# List all interfaces and their IPs:
ip addr show
# Or shorter:
ip a

# Output:
# 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN
#     link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
#     inet 127.0.0.1/8 scope host lo        ← loopback: only this machine
#     inet6 ::1/128 scope host
#
# 2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP
#     link/ether 02:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff   ← MAC address
#     inet 10.0.1.5/24 brd 10.0.1.255 scope global eth0     ← private IP/subnet
#     inet6 fe80::xxx/64 scope link                          ← link-local IPv6
```

### Common Interface Names

```
lo          → Loopback (127.0.0.1). "Talking to yourself."
eth0/eth1   → Ethernet (older naming)
ens5/ens3   → Ethernet (systemd predictable naming, EC2 uses this)
ens6/eth1   → Second network interface (multi-homed EC2)
docker0     → Docker bridge network
veth...     → Virtual ethernet pair (one end in container, one on host)
tun0/tap0   → VPN tunnel interface
```

### Bring Interfaces Up/Down

```bash
# Temporarily bring down/up:
sudo ip link set eth0 down
sudo ip link set eth0 up

# Assign a temporary IP (until reboot):
sudo ip addr add 10.0.1.100/24 dev eth0
sudo ip addr del 10.0.1.100/24 dev eth0

# For permanent config: use netplan (Ubuntu) or NetworkManager (Amazon Linux)
```

---

## IP Routing

When your machine needs to send a packet, the kernel consults the **routing table** to decide where to send it.

```bash
# Show the routing table:
ip route show
# or: ip r

# Output (EC2 instance with private IP 10.0.1.5):
# default via 10.0.1.1 dev eth0 proto dhcp src 10.0.1.5 metric 100
# ↑ Default route: all traffic that doesn't match a more specific route → send to 10.0.1.1 (the gateway)
#
# 10.0.1.0/24 dev eth0 proto kernel scope link src 10.0.1.5
# ↑ Local subnet: traffic to 10.0.1.x → send directly via eth0
```

### How Routing Decisions Are Made

```
Packet destined for 8.8.8.8 (Google DNS):
  Check routing table:
    10.0.1.0/24 matches? 10.0.1.x — NO (8.8.8.8 ≠ 10.0.1.x)
    default (0.0.0.0/0) matches? YES — always matches
  → Send to 10.0.1.1 (the gateway)
  → The gateway (NAT Gateway on AWS) routes it to the internet

Packet destined for 10.0.1.22 (another EC2 in same subnet):
  Check routing table:
    10.0.1.0/24 matches? YES (10.0.1.22 is in this subnet)
  → Send directly via eth0 (no gateway needed)
```

```bash
# Add a static route (temporary):
sudo ip route add 192.168.10.0/24 via 10.0.1.1 dev eth0
# "To reach 192.168.10.x, go through 10.0.1.1"

# Delete a route:
sudo ip route del 192.168.10.0/24

# Test which route will be used for a destination:
ip route get 8.8.8.8
# 8.8.8.8 via 10.0.1.1 dev eth0 src 10.0.1.5 uid 1000

# Trace the path of a packet:
traceroute 8.8.8.8
# or:
tracepath 8.8.8.8
```

---

## DNS Resolution — How Names Become IPs

When you type `curl https://api.example.com`, the OS must resolve `api.example.com` to an IP.

### The Resolution Order

The OS checks sources in this order (defined in `/etc/nsswitch.conf`):

```bash
cat /etc/nsswitch.conf | grep hosts
# hosts: files dns mymachines

# files → check /etc/hosts first
# dns   → then query DNS servers listed in /etc/resolv.conf
# mymachines → systemd-resolved's local machine names
```

### /etc/hosts — Local Overrides

```bash
cat /etc/hosts

# 127.0.0.1   localhost
# 127.0.1.1   ip-10-0-1-5
# ::1         localhost ip6-localhost
#
# Custom entries (useful for testing, or overriding DNS):
# 10.0.2.100  database.internal
# 10.0.2.101  cache.internal

# Add an entry to block a domain:
echo "0.0.0.0 ads.doubleclick.net" >> /etc/hosts
# Requests to ads.doubleclick.net → go nowhere
```

### /etc/resolv.conf — DNS Server Configuration

```bash
cat /etc/resolv.conf

# On EC2 (managed by the DHCP client):
# nameserver 10.0.0.2   ← AWS VPC DNS (always at VPC CIDR + 2)
# search us-east-1.compute.internal ec2.internal
# options edns0 trust-ad

# The VPC DNS (10.0.0.2) resolves:
#   - AWS internal names (*.us-east-1.compute.internal)
#   - Public DNS (via AWS resolver)
#   - Route 53 private hosted zones
```

```bash
# Test DNS resolution:
dig api.example.com
dig @8.8.8.8 api.example.com    # force specific DNS server
nslookup api.example.com
host api.example.com

# Check what the OS resolves (respects /etc/hosts):
getent hosts api.example.com   # shows the actual IP the OS will use

# Quick DNS lookup:
python3 -c "import socket; print(socket.gethostbyname('api.example.com'))"
```

---

## Ports and Sockets

A **port** is a number (1-65535) that differentiates multiple connections to the same IP.

```
Your browser makes two requests to 34.120.100.50:
  Connection 1: from 10.0.1.5:52341 to 34.120.100.50:443
  Connection 2: from 10.0.1.5:52342 to 34.120.100.50:443

The server sees two clients at ports 52341 and 52342.
Your machine has two sockets identified by (src-ip, src-port, dst-ip, dst-port).
```

```
Well-known ports (require root to bind):
  22   → SSH
  80   → HTTP
  443  → HTTPS
  3306 → MySQL
  5432 → PostgreSQL
  6379 → Redis
  8080 → Common alternative HTTP

Ephemeral ports (client-side, OS assigns automatically):
  32768-60999  → Linux default range
  This is the "random" source port your browser uses
```

```bash
# See the ephemeral port range:
cat /proc/sys/net/ipv4/ip_local_port_range
# 32768   60999

# Extend the range if you're running out (many concurrent connections):
echo "1024 65535" | sudo tee /proc/sys/net/ipv4/ip_local_port_range
```

---

## Inspecting Open Connections and Listening Ports

### ss — Socket Statistics (modern netstat)

```bash
# All listening TCP sockets with process info:
ss -tlnp

# Output:
# State  Recv-Q Send-Q Local Address:Port  Peer Address:Port  Process
# LISTEN  0     128    0.0.0.0:80          0.0.0.0:*          users:(("nginx",pid=1234,fd=6))
# LISTEN  0     128    0.0.0.0:443         0.0.0.0:*          users:(("nginx",pid=1234,fd=7))
# LISTEN  0     128    127.0.0.1:3306      0.0.0.0:*          users:(("mysqld",pid=5678,fd=20))
# LISTEN  0     4096   0.0.0.0:22          0.0.0.0:*          users:(("sshd",pid=910,fd=3))

# 0.0.0.0:80 means: listening on ALL interfaces
# 127.0.0.1:3306 means: only on loopback (MySQL not accessible from outside)

# All connections (established, listen, etc.):
ss -tanp

# UDP:
ss -ulnp

# Summary by state:
ss -s
```

### lsof — List Open Files (including sockets)

```bash
# What ports is nginx listening on:
sudo lsof -i -P -n | grep nginx
# nginx   1234  root    6u  IPv4  12345  0t0  TCP *:80 (LISTEN)
# nginx   1234  root    7u  IPv4  12346  0t0  TCP *:443 (LISTEN)

# All network connections:
sudo lsof -i -P -n

# What process is using port 8080:
sudo lsof -i :8080
# or:
sudo ss -tlnp | grep :8080
```

---

## Packet Filtering — iptables

The kernel has a built-in packet filtering framework. On modern systems this is `nftables`, but `iptables` is still the CLI most people know.

```bash
# View current rules:
sudo iptables -L -v -n

# The chains you'll encounter:
# INPUT   → packets coming INTO this machine
# OUTPUT  → packets going OUT FROM this machine
# FORWARD → packets being routed THROUGH this machine

# Allow incoming HTTP:
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Allow SSH only from a specific IP:
sudo iptables -A INPUT -p tcp --dport 22 -s 10.0.1.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j DROP    # drop all other SSH

# Block all outgoing connections to a specific IP:
sudo iptables -A OUTPUT -d 198.51.100.1 -j DROP

# Save rules (Ubuntu):
sudo iptables-save > /etc/iptables/rules.v4

# Save rules (Amazon Linux):
sudo service iptables save
```

**In practice on AWS:** Your EC2 Security Groups handle most firewall rules at the hypervisor level. iptables is a second layer inside the instance. Most EC2 instances have minimal iptables rules — Docker and Kubernetes add many rules automatically.

```bash
# Check if iptables is causing connection issues:
sudo iptables -L -n --line-numbers
# Look for DROP or REJECT rules that might be blocking traffic
```

---

## Network Namespaces — How Docker Works

Linux supports **network namespaces** — each namespace has its own network interfaces, routing table, and firewall rules. Docker uses this to give each container an isolated network stack.

```bash
# List network namespaces:
sudo ip netns list

# Docker container networking:
# Each container has its own namespace
# Inside the container: eth0 at 172.17.0.x
# On the host: veth... interface that connects to docker0 bridge

# See the container's network from the host:
docker inspect <container_id> | grep IPAddress
# 172.17.0.2

# Enter a container's network namespace:
docker exec -it mycontainer ip addr show
# eth0 at 172.17.0.2/16 → isolated interface
```

---

## Troubleshooting Network Issues

```bash
# Scenario: "My app can't connect to the database at 10.0.2.100:5432"

# Step 1: Can you reach the host at all?
ping 10.0.2.100
# If no response: routing issue, security group, or host is down

# Step 2: Can you reach the port?
telnet 10.0.2.100 5432
# or (telnet not always installed):
nc -zv 10.0.2.100 5432          # nc = netcat
# "Connection refused" → host is up but port is closed (check if postgres is running)
# "Connection timed out" → network/firewall is blocking

# Step 3: Is the service even listening?
# (on the database server)
ss -tlnp | grep 5432
# If nothing: postgres isn't running
# If "127.0.0.1:5432": postgres is listening only on localhost (bind_address issue)
# If "0.0.0.0:5432": postgres is listening on all interfaces (should be connectable)

# Step 4: DNS resolution working?
dig db.example.com
getent hosts db.example.com

# Step 5: Check iptables on the destination:
sudo iptables -L INPUT -v -n | grep 5432

# Step 6: Capture packets to see what's happening:
sudo tcpdump -i eth0 host 10.0.2.100 and port 5432 -w /tmp/capture.pcap
# Then inspect: wireshark /tmp/capture.pcap (from your laptop)
# Or quick view:
sudo tcpdump -i eth0 host 10.0.2.100 and port 5432
```

---

## /etc/hosts vs Route53 for Service Discovery

In AWS, your services typically find each other via:
1. **DNS (Route53 private zones)** — `db.internal` resolves to `10.0.2.100`
2. **Environment variables** — injected at deploy time
3. **Service mesh** — Kubernetes Services, Consul, etc.

Avoid `/etc/hosts` for anything beyond local testing — it doesn't scale and isn't consistent across instances.

---

## TCP Connection States

Knowing these helps you debug hanging connections:

```
LISTEN      → Server waiting for connections
SYN_SENT    → Client sent SYN, waiting for SYN-ACK
ESTABLISHED → Both sides connected and communicating
CLOSE_WAIT  → Remote side closed, waiting for local app to close (local app bug if stuck here)
TIME_WAIT   → Connection closed, waiting for delayed packets (normal, lasts ~60s)
FIN_WAIT_2  → Local side sent FIN, waiting for remote to close
```

```bash
# Count connections by state:
ss -tan | awk 'NR>1 {print $1}' | sort | uniq -c | sort -rn

# Lots of CLOSE_WAIT → your application is not properly closing sockets (bug)
# Lots of TIME_WAIT → high connection turnover (normal for busy HTTP servers;
#                     reduce with connection pooling or keepalive)
```

→ Continue to: `07-storage-and-disks.md`
