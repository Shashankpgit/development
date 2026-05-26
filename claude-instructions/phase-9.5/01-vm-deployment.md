# Phase 9.5 — Step 1: VM + Domain Deployment

## What this step covers
Deploy the Personal Vault application to a real cloud VM with a public domain and HTTPS. The docker-compose setup stays identical — the work is in configuring the infrastructure and updating all the places that reference `localhost` to use the real domain.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/017-vm-deployment-plan.md` first
- [ ] Teach the "localhost vs real domain" concept — why it affects Keycloak, Kong, CORS, and the frontend
- [ ] Confirm docker-compose works locally end-to-end before touching anything

---

## Why this step exists

docker-compose works on your laptop. But a real application runs on a server with a public IP and a domain name. Several things break when you move from `localhost` to a real server:

1. **Keycloak issues JWTs with `iss: http://localhost:8080/realms/vault`** — Kong verifies that the `iss` claim matches the consumer key. Once the domain changes, every token's `iss` changes, and Kong rejects them.
2. **Keycloak's redirect URIs** are hardcoded to `http://localhost` — after login, Keycloak sends the user back to the wrong URL.
3. **CORS policy in Kong** allows `http://localhost` — requests from a different origin will be blocked.
4. **The frontend hardcodes `http://localhost:8080`** as the Keycloak URL — it won't reach Keycloak on the real server.
5. **HTTP in production is insecure** — HTTPS is mandatory for OAuth 2.0 to be safe. Tokens travel in plain text over HTTP.

---

## Step 1 — Provision a VM

Minimum requirements: **2 vCPU, 4GB RAM** (Keycloak alone needs ~1GB).

Free/cheap options:
| Provider | Free tier | Notes |
|---|---|---|
| Oracle Cloud | 4 OCPUs, 24GB RAM, Always Free | Best free option |
| Google Cloud | e2-micro, 1 vCPU, 1GB RAM | Too small for Keycloak |
| Hetzner | €4/month, 2 vCPU, 4GB RAM | Best value paid option |
| DigitalOcean | $4/month, 1 vCPU, 1GB RAM | Too small for Keycloak |

Target OS: **Ubuntu 22.04 LTS**.

---

## Step 2 — Install dependencies on the VM

SSH into the VM, then:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER
newgrp docker
```

Verify:
```bash
docker --version
docker compose version
```

---

## Step 3 — Get a free domain (DuckDNS)

1. Go to **duckdns.org** → sign in (GitHub/Google/etc.)
2. Create a subdomain (e.g. `vault-app`) → click "add domain"
3. Enter the VM's public IP → click "update ip"
4. Verify: `ping vault-app.duckdns.org` resolves to VM IP

DuckDNS gives you a free `*.duckdns.org` subdomain that points to any IP you set. It also supports Let's Encrypt via a DNS challenge.

---

## Step 4 — Open firewall ports on the VM

Required ports:
| Port | Purpose |
|---|---|
| 22 | SSH (already open) |
| 80 | HTTP — needed for Let's Encrypt ACME challenge |
| 443 | HTTPS — the app |

How to open depends on the provider (Oracle: Security Lists, Google: Firewall Rules, Hetzner: Firewall tab). Also run on the VM:
```bash
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 22
sudo ufw enable
```

---

## Step 5 — Update application config for the real domain

**DO THIS BEFORE deploying to the VM.** Commit the changes so they're in the repo.

### 5a — `vault/docker-compose.yml` (Keycloak)
Add `KC_PROXY: edge` and update hostname:
```yaml
KC_HOSTNAME: vault-app.duckdns.org
KC_PROXY: edge          # tells Keycloak it's behind a TLS-terminating proxy
KC_HTTP_PORT: 8080
```
`KC_PROXY: edge` is required when Keycloak runs behind nginx/Let's Encrypt — without it, Keycloak builds redirect URLs with `http://` even though nginx is serving `https://`.

### 5b — `vault/keycloak/realm-export.json`
Change `vault-frontend` client's `redirectUris`:
```json
"redirectUris": ["https://vault-app.duckdns.org/*"]
```
And `webOrigins`:
```json
"webOrigins": ["https://vault-app.duckdns.org"]
```

### 5c — `vault/kong/kong.yml`
Two changes:
```yaml
# Consumer key — must match the `iss` claim in Keycloak tokens
key: https://vault-app.duckdns.org/realms/vault

# CORS origin
origins:
  - https://vault-app.duckdns.org
```

### 5d — `vault/frontend/src/keycloak.js`
Change `KEYCLOAK_URL` from a hardcoded string to a Vite env var:
```js
const KEYCLOAK_URL = import.meta.env.VITE_KEYCLOAK_URL;
```
Then in `vault/frontend/.env` (local dev):
```
VITE_KEYCLOAK_URL=http://localhost:8080
```
And in `vault/frontend/.env.production` (VM deploy — baked at build time):
```
VITE_KEYCLOAK_URL=https://vault-app.duckdns.org
```

### 5e — `vault/nginx/nginx.conf`
Add HTTP → HTTPS redirect. Certbot will add the HTTPS block automatically, but prepare the structure:
```nginx
server {
    listen 80;
    server_name vault-app.duckdns.org;
    # certbot will add: return 301 https://$host$request_uri;
}
```

---

## Step 6 — Set up HTTPS with Let's Encrypt (Certbot)

Certbot must run on the VM **before** docker-compose, because it needs port 80.

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot certonly --standalone -d vault-app.duckdns.org
```

`--standalone` tells certbot to spin up its own temporary server on port 80 for the ACME challenge. Cert files land in `/etc/letsencrypt/live/vault-app.duckdns.org/`.

Then mount the certs into the nginx container via docker-compose:
```yaml
nginx:
  volumes:
    - /etc/letsencrypt:/etc/letsencrypt:ro
```

And update `nginx.conf` to use them:
```nginx
server {
    listen 443 ssl;
    server_name vault-app.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/vault-app.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vault-app.duckdns.org/privkey.pem;

    location / {
        # existing proxy config
    }
}

server {
    listen 80;
    server_name vault-app.duckdns.org;
    return 301 https://$host$request_uri;
}
```

Auto-renewal:
```bash
sudo certbot renew --dry-run    # test renewal
# certbot sets up a systemd timer automatically
```

---

## Step 7 — Clone repo and deploy on the VM

```bash
git clone <repo-url> ~/development
cd ~/development/vault

# create .env files (never commit secrets)
cp backend/.env.example backend/.env
# fill in: DATABASE_URL, VAULT_ENCRYPTION_KEY, POSTGRES_* vars, KEYCLOAK_* vars

docker compose up -d --build
```

---

## Step 8 — Verify end-to-end

```bash
# All containers running
docker compose ps

# Check logs
docker compose logs keycloak --tail=50
docker compose logs api --tail=20
```

Then in the browser:
- `https://vault-app.duckdns.org` → vault app loads (HTTPS lock icon)
- Register → login → create note → delete note
- Logout → redirect to Keycloak login page (not localhost)

---

## Concepts to teach during this step

- **Why KC_PROXY: edge** — Keycloak runs on HTTP internally but must generate HTTPS URLs for redirects. `edge` mode tells it to trust the `X-Forwarded-Proto: https` header that nginx sets.

- **Let's Encrypt + ACME** — Free TLS certificates. Let's Encrypt is a CA. Certbot speaks the ACME protocol: proves you control the domain by serving a challenge on port 80, then gets a 90-day cert.

- **Why certs expire in 90 days** — Forces automation of renewal. Certbot auto-renews before expiry via a systemd timer.

- **HTTP → HTTPS redirect** — Always redirect port 80 to 443. Never serve content on HTTP once HTTPS is available.

- **Environment differences** — `localhost` vs production is the first time the student sees that config must be environment-specific. Vite's `.env.production` is a good concrete example.

---

## kubectl commands to learn
N/A — this phase uses docker-compose, not Kubernetes.

---

## What NOT to do in this step

- Do NOT put real secrets in `.env.production` or commit them
- Do NOT skip HTTPS — Keycloak's OAuth redirect flow requires secure origins in production
- Do NOT expose port 8080 (Keycloak admin) publicly without auth — leave it internal or protect it
- Do NOT use `--import-realm` in production without understanding the key material implications

---

## Success criteria

```bash
# On the VM
docker compose ps          # all containers Up

# In the browser
# https://vault-app.duckdns.org → loads vault app with HTTPS
# Register new user → automatic login → create note → works
# Logout → Keycloak login page (with vault theme) on real domain
# No "localhost" appears anywhere in the browser's Network tab requests
```

---

## After this phase → Phase 10 (Kubernetes)

Once the VM deployment is stable, Phase 10 translates this same docker-compose setup into Kubernetes manifests, deployed either locally (k3d) or on the same VM.
