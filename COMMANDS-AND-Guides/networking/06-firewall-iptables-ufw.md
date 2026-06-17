# Networking — Part 06: Firewalls — iptables, ufw, nftables

**20-minute read. Firewalls cause ~30% of "service unreachable" issues. Know them to stop guessing.**

---

## The Linux Firewall Stack

```
Network packet arrives
        │
        ▼
   Kernel (netfilter)     ← the actual filtering framework
        │
        ▼
   nftables / iptables    ← tools to configure netfilter rules
        │
        ▼
   ufw / firewalld        ← friendly wrappers around iptables/nftables
```

Most Ubuntu/Debian servers use either:
- **ufw** (Uncomplicated Firewall) — simple, human-readable wrapper
- **iptables** — the underlying raw tool (used by Docker, Kubernetes)

On modern systems (Ubuntu 20.04+), nftables is the underlying kernel framework, with iptables running in compatibility mode (`iptables-nft`).

---

## ufw — The DevOps-Friendly Firewall

`ufw` is what you use for server-level firewall management. It's much simpler than raw iptables.

```bash
# Check ufw status
sudo ufw status
# Status: active  or  Status: inactive

# Verbose status (shows all rules)
sudo ufw status verbose

# Enable/disable ufw
sudo ufw enable
sudo ufw disable
```

### ufw Rules

```bash
# Allow a port (all IPs)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp         # SSH — always allow this BEFORE enabling ufw!
sudo ufw allow 5432/tcp       # PostgreSQL

# Allow by service name (from /etc/services)
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

# Allow from a specific IP
sudo ufw allow from 10.0.1.100 to any port 22
sudo ufw allow from 10.0.1.0/24 to any port 5432   # allow whole subnet

# Allow port range
sudo ufw allow 8000:9000/tcp

# Deny a port (explicit block)
sudo ufw deny 3306/tcp

# Delete a rule
sudo ufw delete allow 3306/tcp
sudo ufw delete 3     # delete rule number 3 (from: ufw status numbered)

# Numbered rules (for deletion)
sudo ufw status numbered
```

### Default Policies

```bash
# Deny all incoming, allow all outgoing (typical server config)
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Then explicitly allow what you need:
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
```

### Real-World ufw Config for a Web Server

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'    # allows 80 + 443
sudo ufw allow from 10.0.0.0/8 to any port 5432   # postgres only from internal
sudo ufw allow from 10.0.0.0/8 to any port 9090   # prometheus only internally
sudo ufw enable
sudo ufw status verbose
```

---

## iptables — The Raw Firewall

You MUST understand iptables because:
- Docker manipulates iptables directly
- Kubernetes (kube-proxy) writes iptables rules
- You'll debug "my Docker port mapping stopped working" — it's iptables
- Old servers and scripts use iptables directly

### Chains and Tables

iptables organizes rules into **tables** and **chains**:

```
Tables:
  filter   — decides whether to ACCEPT or DROP packets (what most people think of as firewall)
  nat      — rewrites source/destination IPs (NAT, port forwarding)
  mangle   — modifies packet headers
  raw      — connection tracking exemptions

Chains (in the filter table):
  INPUT    — packets destined FOR this machine
  OUTPUT   — packets originating FROM this machine
  FORWARD  — packets being routed THROUGH this machine

Each chain has a default policy (ACCEPT or DROP).
Each rule in a chain says: if packet matches [criteria], do [action].
Actions: ACCEPT, DROP, REJECT, LOG, RETURN, jump to another chain
```

### Reading iptables Rules

```bash
# List all rules in the filter table (INPUT chain)
sudo iptables -L INPUT -n -v
# -L = list rules
# -n = don't resolve IPs/ports
# -v = verbose (show packet/byte counts and interface)

# List all rules including line numbers
sudo iptables -L INPUT -n -v --line-numbers

# List all tables
sudo iptables -L -n -v -t filter    # filter table
sudo iptables -L -n -v -t nat       # NAT rules
sudo iptables -L -n -v -t mangle    # mangle rules

# Save current rules to a file
sudo iptables-save > /tmp/iptables-rules.txt

# Restore rules from a file
sudo iptables-restore < /tmp/iptables-rules.txt
```

### Writing iptables Rules

```bash
# Allow SSH on port 22
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP and HTTPS
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow established/related connections (crucial — without this, all responses are blocked)
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback traffic
sudo iptables -A INPUT -i lo -j ACCEPT

# Drop everything else
sudo iptables -A INPUT -j DROP

# Allow from specific IP
sudo iptables -A INPUT -s 10.0.1.100 -p tcp --dport 5432 -j ACCEPT

# Allow from subnet
sudo iptables -A INPUT -s 10.0.0.0/8 -p tcp --dport 5432 -j ACCEPT

# Block a specific IP (DDoS mitigation)
sudo iptables -I INPUT -s 1.2.3.4 -j DROP    # -I inserts at top
```

### Manage Rules

```bash
# Add rule at end of chain (-A = append)
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# Insert rule at specific position (-I = insert, position 1 = first)
sudo iptables -I INPUT 1 -p tcp --dport 8080 -j ACCEPT

# Delete a specific rule
sudo iptables -D INPUT -p tcp --dport 8080 -j ACCEPT

# Delete rule by line number (from --line-numbers)
sudo iptables -D INPUT 3

# Flush all rules in a chain
sudo iptables -F INPUT

# Set default policy
sudo iptables -P INPUT DROP
sudo iptables -P INPUT ACCEPT
```

---

## Docker and iptables — How Docker Manages Ports

Docker adds its own iptables rules automatically. This is why `ufw allow 8080` might not work for a Docker container.

```bash
# See Docker's NAT rules (port mappings)
sudo iptables -t nat -L DOCKER -n -v --line-numbers

# Example: docker run -p 8080:3000 vault-api
# Docker adds:
# Chain DOCKER:
# DNAT  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:8080 to:172.17.0.2:3000
#              ↑ external port          ↑ container IP:internal port

# Docker's FORWARD chain rule (allows forwarding to containers)
sudo iptables -L DOCKER-USER -n -v

# If you block port 8080 with ufw but run a Docker container on it:
# ufw's INPUT rules DON'T affect Docker port mappings!
# Docker uses FORWARD chain, not INPUT.
# Solution: add rules to DOCKER-USER chain (Docker respects this)
sudo iptables -I DOCKER-USER -p tcp --dport 3000 -s 10.0.0.0/8 -j ACCEPT
sudo iptables -I DOCKER-USER -p tcp --dport 3000 -j DROP
```

---

## Kubernetes and iptables — What kube-proxy Does

kube-proxy adds iptables rules to implement Services. Every ClusterIP Service = a chain of DNAT rules.

```bash
# See Kubernetes NAT rules (Services)
sudo iptables -t nat -L -n | grep KUBE

# Find the rules for a specific service
sudo iptables -t nat -L KUBE-SERVICES -n | grep 10.96.45.23   # service ClusterIP

# Output shows:
# KUBE-SVC-XXXX  tcp  --  0.0.0.0/0  10.96.45.23  tcp dpt:80
# This means: traffic to 10.96.45.23:80 → goes to KUBE-SVC-XXXX chain → DNAT to a pod IP
```

This is why Kubernetes needs `iptables` to work. If iptables rules are corrupted or a node has `--no-iptables`, Services stop working.

---

## nftables — The Modern iptables

Ubuntu 20.04+ uses nftables under the hood. If you see `iptables-nft` in the path, you're already using nftables via the compat layer.

```bash
# Check which iptables backend you're using
iptables --version
# iptables v1.8.7 (nf_tables)   ← using nftables backend
# iptables v1.8.7 (legacy)      ← using legacy iptables backend

# List nftables rules directly
sudo nft list ruleset

# nftables equivalent of common iptables rules:
sudo nft add rule inet filter input tcp dport 80 accept
sudo nft add rule inet filter input tcp dport 22 accept
sudo nft list table inet filter
```

---

## Real-World Scenario: Docker Port Not Accessible From Outside

```bash
# docker run -d -p 8080:3000 vault-api
# curl http://server-ip:8080 times out from another machine

# Step 1: Is Docker's NAT rule there?
sudo iptables -t nat -L DOCKER -n | grep 8080
# If missing → docker restart or re-run the container

# Step 2: Is FORWARD allowed for Docker traffic?
sudo iptables -L FORWARD -n | grep DOCKER
# Should see: DOCKER-USER, DOCKER-ISOLATION-STAGE-1/2, DOCKER

# Step 3: Is ufw blocking it? (ufw blocks INPUT but Docker uses FORWARD)
sudo ufw status | grep 8080
# Even if ufw doesn't have a rule for 8080, Docker port mappings bypass ufw INPUT rules

# Step 4: Is the server's cloud security group blocking port 8080?
# Check AWS Security Group or GCP Firewall Rules in the cloud console
# This is EXTERNAL to the server — iptables/ufw can't show these rules

# Step 5: Test locally on the server first
curl http://localhost:8080     # does it work locally?
# If yes → problem is external firewall (security group), not the server's iptables
# If no → problem is inside Docker or the app
```

---

## Common Misunderstanding: "ufw enable + ufw allow 80 is enough for Docker"

**The misunderstanding:** "I enabled ufw and allowed port 80. My Docker container is still accessible from the internet."

**The reality:** Docker writes iptables rules that BYPASS ufw. When ufw is enabled, Docker's DNAT rules still forward traffic directly — they live in the `nat` table's PREROUTING chain, which runs before ufw's `INPUT` chain filter.

This means: **Docker ignores ufw's INPUT rules for published ports.**

To restrict Docker's exposed ports with ufw, you must:
1. Either bind Docker to `127.0.0.1` only: `docker run -p 127.0.0.1:8080:3000 vault-api`
2. Or use the `DOCKER-USER` chain (Docker guarantees it won't touch this chain):

```bash
# Block all external access to Docker ports except from specific IP
sudo iptables -I DOCKER-USER -i eth0 ! -s 10.0.0.0/8 -j DROP
# Then allow specific ports:
sudo iptables -I DOCKER-USER -i eth0 -p tcp --dport 3000 -s 0.0.0.0/0 -j ACCEPT
```

The safest practice: use cloud-level security groups/firewall rules rather than relying on ufw+Docker interactions.

→ Continue to: `07-tls-ssl-certificates.md`
