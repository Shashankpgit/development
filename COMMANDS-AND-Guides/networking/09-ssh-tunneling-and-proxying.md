# Networking — Part 09: SSH Tunneling, Port Forwarding, and Proxying

**20-minute read. SSH tunnels are how you access anything that's not publicly exposed — databases, internal dashboards, staging environments.**

---

## Why SSH Tunnels?

In any secure production setup:
- PostgreSQL listens on `127.0.0.1:5432` only (not exposed externally)
- Grafana runs on port 3000 on an internal-only server
- Kubernetes API server is not publicly accessible
- RDS databases are in a private subnet with no public IP

To access these securely from your laptop, you create an SSH tunnel — an encrypted channel that forwards a local port through an SSH connection to a remote resource.

---

## Local Port Forwarding — Access a Remote Resource Locally

**Use case:** The resource is behind a server you can SSH into, but you can't reach it directly.

```bash
ssh -L [local_port]:[target_host]:[target_port] [ssh_server]

# Syntax breakdown:
# local_port  = port on YOUR machine
# target_host = hostname or IP as seen FROM the SSH server
# target_port = port on target_host
# ssh_server  = the SSH server to connect through
```

### Accessing a Remote Database

```bash
# PostgreSQL on the app server (only accessible from app server itself)
ssh -L 5432:localhost:5432 ubuntu@10.0.1.50

# Now in another terminal:
psql -h localhost -p 5432 -U vaultadmin -d vault
# This connects to PostgreSQL on 10.0.1.50 as if it were local!
```

```bash
# Access RDS in a private subnet (through a bastion/jump host)
# RDS: vault-db.abc123.ap-south-1.rds.amazonaws.com (not publicly accessible)
# Bastion: 54.100.200.50 (public IP)

ssh -L 5432:vault-db.abc123.ap-south-1.rds.amazonaws.com:5432 ubuntu@54.100.200.50

# Now connect from your laptop:
psql -h localhost -p 5432 -U admin -d vault
# Traffic path: laptop → (SSH) → bastion → (TCP) → RDS
```

```bash
# Access internal Grafana dashboard
ssh -L 3000:localhost:3000 ubuntu@internal-monitor-server

# Then open http://localhost:3000 in your browser
# Your browser thinks Grafana is local — it's actually on the remote server
```

### Access Multiple Services in One Command

```bash
# Tunnel to Grafana, Prometheus, AND Postgres simultaneously
ssh -L 3000:localhost:3000 \
    -L 9090:localhost:9090 \
    -L 5432:localhost:5432 \
    ubuntu@monitoring-server

# Now:
# http://localhost:3000 → Grafana
# http://localhost:9090 → Prometheus
# localhost:5432        → PostgreSQL
```

### Non-Blocking Tunnel (Background)

```bash
# -N = don't execute a remote command (just tunnel)
# -f = background the SSH process
ssh -N -f -L 5432:localhost:5432 ubuntu@10.0.1.50

# Stop the tunnel later:
pkill -f "ssh -N -f -L 5432"
# Or find the PID:
ps aux | grep "ssh -N"
```

---

## Remote Port Forwarding — Expose Your Local Service to a Remote Server

**Use case:** You're developing locally and want someone on a remote server to reach your laptop's service.

```bash
ssh -R [remote_port]:[local_host]:[local_port] [ssh_server]
```

```bash
# Your laptop is running a dev server on port 3000.
# A colleague on 10.0.1.50 wants to test it.

ssh -R 8080:localhost:3000 ubuntu@10.0.1.50

# Now on 10.0.1.50:
curl http://localhost:8080    # reaches YOUR laptop's port 3000

# Make it accessible to all IPs on the remote server (not just localhost):
ssh -R 0.0.0.0:8080:localhost:3000 ubuntu@10.0.1.50
# (requires GatewayPorts yes in sshd_config on the remote server)
```

**Real-world use:** Webhooks. Services like Stripe, GitHub, Slack send webhooks to a public URL. During development, use remote forwarding to receive webhooks on your local machine.

---

## Dynamic Port Forwarding — SOCKS Proxy

**Use case:** Route ALL your traffic through a remote server — like a VPN. Access any resource the remote server can reach.

```bash
# Create a SOCKS5 proxy on local port 1080
ssh -D 1080 ubuntu@jumphost.example.com

# Now configure your browser/curl to use this SOCKS proxy:
curl --socks5 localhost:1080 https://internal-service.example.com

# Or export for all commands:
export ALL_PROXY=socks5://localhost:1080
curl https://internal-service.example.com

# In Firefox/Chrome: Settings → Network → Manual proxy → SOCKS Host: localhost, Port: 1080
```

**For accessing all Kubernetes cluster-internal services:**
```bash
# Create a SOCKS proxy through the cluster's bastion
ssh -D 1080 -N ubuntu@k8s-bastion.example.com

# Now curl can reach internal Kubernetes services by ClusterIP:
curl --socks5 localhost:1080 http://10.96.45.23:80/health
# Or by DNS name (your DNS must resolve cluster names):
curl --socks5 localhost:1080 http://vault-api-service.production.svc.cluster.local/health
```

---

## Jump Hosts (Bastion Hosts)

A jump host (bastion) is a server in a DMZ that you SSH into first, then SSH from there to internal servers.

### Direct Jump (Modern Way)

```bash
# SSH to 10.0.1.100 by jumping through bastion at 54.100.200.50
ssh -J ubuntu@54.100.200.50 ubuntu@10.0.1.100

# Multiple jumps
ssh -J ubuntu@54.100.200.50,ubuntu@10.0.1.50 ubuntu@10.0.2.100
```

### SSH Config for Jump Hosts (Save Typing)

```bash
# ~/.ssh/config
Host bastion
    HostName 54.100.200.50
    User ubuntu
    IdentityFile ~/.ssh/production.pem

Host internal-*
    User ubuntu
    IdentityFile ~/.ssh/production.pem
    ProxyJump bastion

Host internal-app
    HostName 10.0.1.100

Host internal-db
    HostName 10.0.1.50

Host internal-monitor
    HostName 10.0.1.60
```

```bash
# Now you can just:
ssh internal-app        # automatically jumps through bastion
ssh internal-db
ssh internal-monitor

# SCP through jump host automatically
scp internal-app:/var/log/app.log ./app.log

# SSH with tunnel through jump host:
ssh -L 5432:localhost:5432 internal-db
```

---

## SSH Config Best Practices

```bash
# ~/.ssh/config — full example for DevOps work

Host *
    # Keep connection alive (prevent timeout)
    ServerAliveInterval 60
    ServerAliveCountMax 3
    
    # Reuse existing connections (faster for multiple sessions)
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600     # keep connection for 10 minutes after last session

Host prod-bastion
    HostName 54.100.200.50
    User ubuntu
    IdentityFile ~/.ssh/production.pem
    # Port 22

Host prod-app-*
    User ubuntu
    IdentityFile ~/.ssh/production.pem
    ProxyJump prod-bastion

Host prod-app-1
    HostName 10.0.1.10

Host prod-app-2
    HostName 10.0.1.11

Host prod-db
    HostName 10.0.2.50
    User ubuntu
    IdentityFile ~/.ssh/production.pem
    ProxyJump prod-bastion
    # Local tunnel to postgres automatically
    LocalForward 15432 localhost:5432

Host k8s-proxy
    HostName 54.200.100.50
    User ubuntu
    DynamicForward 1080    # SOCKS proxy
    RequestTTY no
    ExitOnForwardFailure yes
```

```bash
# Create the sockets directory
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets

# Now:
ssh prod-app-1          # goes through bastion automatically
ssh prod-db             # tunnels port 15432 → postgres automatically
ssh k8s-proxy           # SOCKS proxy on port 1080
```

---

## kubectl Port Forward (Kubernetes-Native Tunneling)

For Kubernetes, you don't need SSH — `kubectl port-forward` does the same thing using the Kubernetes API.

```bash
# Forward local port 8080 to pod's port 3000
kubectl port-forward pod/vault-api-7d4b9c-xyz 8080:3000 -n production

# Forward to a service (load balances across all healthy pods)
kubectl port-forward service/vault-api-service 8080:80 -n production

# Forward to a deployment
kubectl port-forward deployment/vault-api 8080:3000 -n production

# Forward to postgres StatefulSet
kubectl port-forward statefulset/postgres 5432:5432 -n production

# Background and bind to all interfaces (accessible from other machines)
kubectl port-forward service/grafana 0.0.0.0:3000:3000 -n monitoring &
```

---

## Real-World Scenario: Accessing Multiple AWS RDS Databases

```bash
# You manage 3 databases: prod, staging, dev
# All in private subnets, one bastion host with public IP

# ~/.ssh/config
Host aws-bastion
    HostName 54.100.200.50
    User ubuntu
    IdentityFile ~/.ssh/aws.pem

# Tunnel script: ~/bin/db-tunnel
#!/bin/bash
echo "Starting database tunnels..."
ssh -N -f \
    -L 5433:prod-db.abc123.rds.amazonaws.com:5432 \
    -L 5434:staging-db.def456.rds.amazonaws.com:5432 \
    -L 5435:dev-db.ghi789.rds.amazonaws.com:5432 \
    aws-bastion

echo "Tunnels open:"
echo "  prod:    localhost:5433"
echo "  staging: localhost:5434"
echo "  dev:     localhost:5435"

# Usage:
# db-tunnel
# psql -h localhost -p 5433 -U admin prod     # connects to prod RDS
# psql -h localhost -p 5434 -U admin staging  # connects to staging RDS
```

---

## Common Misunderstanding: "SSH tunnels are secure because SSH is encrypted"

**The misunderstanding:** "My SSH tunnel is encrypted — the traffic is safe."

**The reality:** The SSH tunnel encrypts traffic between YOUR machine and the SSH server. But once it leaves the SSH server towards the destination, traffic is unencrypted unless the destination application also uses TLS.

```
Your laptop ──[encrypted SSH]──► Bastion ──[UNENCRYPTED]──► RDS:5432
```

For PostgreSQL: `sslmode=require` in your connection string ensures TLS from bastion to RDS.
For HTTP: use `https://` not `http://` when accessing through the tunnel.

The SSH tunnel protects:
- Traffic between YOU and the bastion (prevents interception on your network)
- Your credentials (they travel inside the encrypted SSH channel)

The SSH tunnel does NOT protect:
- Traffic between the bastion and the final destination (unless the app also uses TLS)

This is usually fine for internal networks, but worth knowing when the bastion and RDS are in different networks.

→ Continue to: `10-container-and-k8s-networking.md`
