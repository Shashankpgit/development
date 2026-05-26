# KT — GCP VM Setup for Personal Vault

## Minimum Requirements

Our stack has 5 services. Here's how much RAM each needs:

| Service | Minimum RAM | Notes |
|---|---|---|
| PostgreSQL | 256 MB | Light for small data |
| FastAPI (api) | 256 MB | Python app, light |
| Keycloak | 768 MB – 1 GB | Heavy — Java-based, this is the bottleneck |
| Kong | 256 MB | Lua-based, light |
| Nginx | 64 MB | Very light |
| **Total** | **~2 GB** | 4 GB recommended for headroom |

**Recommended GCP machine: `e2-medium`**
- 2 vCPU (shared core)
- 4 GB RAM
- ~$0.033/hour → ~$24/month
- With GCP's $300 free trial credits: runs for ~12 months free

**Minimum viable machine: `e2-small`**
- 2 vCPU (shared core)
- 2 GB RAM
- ~$0.017/hour → ~$12/month
- Keycloak will start but will be slow and may OOM under load

> Stick with `e2-medium`. Keycloak on 2GB is painful.

---

## Part 1 — Create the VM in GCP Console

### Step 1 — Open Compute Engine

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Select or create a project
3. In the left sidebar: **Compute Engine → VM instances**
4. Click **Create Instance**

---

### Step 2 — Name and Region

| Field | Value |
|---|---|
| Name | `vault-vm` |
| Region | `us-central1` (cheapest region) |
| Zone | `us-central1-a` |

> Region affects price and latency. `us-central1` is GCP's cheapest.

---

### Step 3 — Machine Configuration

| Field | Value |
|---|---|
| Machine family | **General purpose** |
| Series | **E2** |
| Machine type | **e2-medium** (2 vCPU, 4 GB RAM) |

---

### Step 4 — Boot Disk

Click **Change** under Boot disk:

| Field | Value |
|---|---|
| Operating system | **Ubuntu** |
| Version | **Ubuntu 22.04 LTS** |
| Boot disk type | **Standard persistent disk** |
| Size | **20 GB** (default is fine) |

> Ubuntu 22.04 LTS = Long Term Support, supported until 2027. Stable for servers.

---

### Step 5 — Firewall

Check both boxes:
- ✅ **Allow HTTP traffic** (port 80)
- ✅ **Allow HTTPS traffic** (port 443)

> This opens ports 80 and 443 on GCP's firewall. Port 22 (SSH) is open by default.

---

### Step 6 — Create

Click **Create**. VM will be ready in ~30 seconds.

---

## Part 2 — Note your VM's external IP

Once the VM is created, you'll see it in the VM instances list with an **External IP** like `34.123.45.67`.

**This is the IP you'll point your DuckDNS domain at.**

> Important: By default this is an **ephemeral IP** — it changes if you stop/start the VM. To make it permanent, reserve a **static external IP** (covered below).

---

## Part 3 — Reserve a Static External IP (important)

An ephemeral IP changes every time the VM restarts. Your domain would stop working. Reserve a static IP:

1. In GCP Console: **VPC Network → IP addresses**
2. Find the IP currently assigned to `vault-vm`
3. Click the three dots → **Promote to static address**
4. Name it `vault-static-ip` → **Reserve**

Now the IP is permanent and won't change.

---

## Part 4 — SSH into the VM

GCP provides browser-based SSH — no setup needed:

1. Go to **Compute Engine → VM instances**
2. Find `vault-vm` → click **SSH** button in the Connect column
3. A browser terminal opens

Alternatively, from your local machine (if you have gcloud CLI):
```bash
gcloud compute ssh vault-vm --zone us-central1-a
```

---

## Part 5 — Install Docker on the VM

Once SSH'd in, run these commands **one at a time**:

```bash
# Update package list
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install -y docker.io

# Install docker-compose plugin (v2)
sudo apt install -y docker-compose-v2

# Install git
sudo apt install -y git

# Allow your user to run Docker without sudo
sudo usermod -aG docker $USER

# Apply group change (or log out and back in)
newgrp docker
```

Verify:
```bash
docker --version
docker compose version
git --version
```

Expected output:
```
Docker version 24.x.x
Docker Compose version v2.x.x
git version 2.x.x
```

---

## Part 6 — Why we do NOT open port 8080 for Keycloak

You might wonder: "Keycloak runs on port 8080 — shouldn't I open that?"

**No. Never expose Keycloak (or any internal service) directly.**

All public traffic enters on **port 443 (HTTPS) only**, through nginx. Nginx then decides where to route each request internally based on the URL path. Keycloak, Kong, and the API all run on internal Docker ports that are never reachable from the internet.

```
Internet
    │
    ▼  port 443 only
  Nginx  ◄── single public entry point
    │
    ├── /realms/*  and  /auth/*  ──→  Keycloak  (internal port 8080)
    ├── /api/*  ──────────────────→  Kong       (internal port 8000)
    └── /*  ───────────────────────→  Frontend   (static files)
```

This means:
- Keycloak's admin console (`/auth/admin`) is accessible via `https://vault-app.duckdns.org/auth/admin` — through nginx, over HTTPS
- No service has a direct public port except nginx
- An attacker cannot reach Keycloak, Kong, or PostgreSQL directly even if they know the ports

This is the correct production pattern. Nginx is the **only door** into the system.

---

## Part 7 — Verify the VM is reachable

On the VM, run:
```bash
curl ifconfig.me
```
This returns the VM's public IP. It should match the external IP shown in GCP Console.

---

## Summary Checklist

- [ ] VM created: `e2-medium`, Ubuntu 22.04, region `us-central1`
- [ ] Firewall: HTTP (80) and HTTPS (443) enabled — nothing else
- [ ] Static external IP reserved
- [ ] SSH into the VM works
- [ ] Docker + docker-compose + git installed
- [ ] External IP noted — ready to configure DuckDNS

---

## Next step

Once the VM is ready and you have the external IP → set up DuckDNS to point your free domain at it.
