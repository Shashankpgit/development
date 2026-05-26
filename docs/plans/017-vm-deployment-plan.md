# 017 — Phase 9.5: VM + Domain Deployment

## What we are doing

Deploying the Personal Vault to a real cloud VM with a public domain and HTTPS.
docker-compose stays unchanged as the deployment mechanism — the work is in:
1. Provisioning a VM and installing Docker
2. Getting a free domain (DuckDNS) and pointing it to the VM
3. Setting up HTTPS with Let's Encrypt (Certbot)
4. Updating all places in the app that reference `localhost` to use the real domain
5. Running docker-compose on the VM

## What is NOT in scope for this step

- Kubernetes (Phase 10)
- CI/CD pipeline (Phase 12)
- Monitoring (Phase 13)
- Email/SMTP for Keycloak (future)

## Steps

1. KT — understand what breaks when moving from localhost to a real domain
2. Provision VM (2 vCPU, 4GB RAM minimum)
3. Install Docker + docker-compose + git on VM
4. Get a free DuckDNS domain, point it to VM IP
5. Open firewall ports (80, 443)
6. Get SSL certificate with Certbot
7. Update app config for real domain (Keycloak, Kong, frontend, nginx)
8. Clone repo + deploy on VM
9. Verify end-to-end

## Files that will change

| File | Change |
|---|---|
| `vault/docker-compose.yml` | Add `KC_PROXY: edge`, update KC_HOSTNAME |
| `vault/keycloak/realm-export.json` | Update redirectUris + webOrigins to real domain |
| `vault/kong/kong.yml` | Update CORS origin + JWT consumer key (iss) |
| `vault/frontend/src/keycloak.js` | Make KEYCLOAK_URL an env var |
| `vault/frontend/.env.example` | Add VITE_KEYCLOAK_URL |
| `vault/nginx/nginx.conf` | Add HTTPS + HTTP→HTTPS redirect blocks |
| `vault/docker-compose.yml` | Mount Let's Encrypt certs into nginx |

## Concepts covered

- Why `localhost` breaks in production
- KC_PROXY: edge — what it does and why Keycloak needs it behind a proxy
- Let's Encrypt + ACME protocol — how free TLS works
- Environment-specific config (Vite .env.production)
- HTTP → HTTPS redirect
