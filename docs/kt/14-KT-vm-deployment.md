# KT — VM Deployment & Domain Setup

## What this document covers

Everything you need to understand before deploying the Personal Vault to a real server:
- Why `localhost` breaks in production
- What a domain is and how DNS works
- What HTTPS is and why it's mandatory
- How Let's Encrypt gives you free TLS certificates
- What changes in the app config and why

---

## Part 1 — Why `localhost` breaks in production

Right now the app runs on your laptop. Every service talks to `localhost`. When you move to a real server, `localhost` no longer refers to your laptop — it refers to the server itself. But more importantly, **your users' browsers** are what make the requests, and their `localhost` is their own machine, which has nothing on port 8080.

The app has `localhost` hardcoded in 4 places. Each breaks for a different reason.

---

### Problem 1 — Keycloak's JWT issuer (`iss` claim)

When Keycloak issues a token, it embeds the server URL inside the JWT:

```json
{
  "iss": "http://localhost:8080/realms/vault",
  "sub": "abc123",
  "exp": 1779795402
}
```

Kong reads that `iss` value and compares it against the `key` field in `kong.yml`:

```yaml
consumers:
  - username: keycloak-issuer
    jwt_secrets:
      - key: http://localhost:8080/realms/vault   ← must match iss exactly
```

On a real server with domain `vault-app.duckdns.org`, Keycloak will issue:

```json
{ "iss": "https://vault-app.duckdns.org/realms/vault" }
```

Kong still has `key: http://localhost:8080/realms/vault` → **mismatch → 401 on every request**.

**Fix**: Change `KC_HOSTNAME` in docker-compose and update the consumer key in kong.yml to match.

---

### Problem 2 — Keycloak redirect URIs

After the user logs in, Keycloak redirects the browser back to your app with `?code=`. It only redirects to URLs in the **allowed redirect URIs** list.

Right now the list is: `["http://localhost/*"]`

When a real user logs in from `https://vault-app.duckdns.org`, Keycloak refuses to redirect there → **login fails with "Invalid redirect URI" error**.

**Fix**: Update `redirectUris` in `realm-export.json` to `["https://vault-app.duckdns.org/*"]`.

---

### Problem 3 — Kong's CORS policy

When the browser at `https://vault-app.duckdns.org` makes an API request, it sends:

```
Origin: https://vault-app.duckdns.org
```

Kong's CORS plugin currently allows only `http://localhost`. The domain doesn't match → **Kong returns a CORS error → every API call is blocked**.

**Fix**: Update Kong's CORS `origins` list to `https://vault-app.duckdns.org`.

---

### Problem 4 — Frontend hardcodes `http://localhost:8080`

In `keycloak.js`, the Keycloak URL is:

```js
const KEYCLOAK_URL = 'http://localhost:8080';
```

When a real user visits your site and clicks Login, the browser tries to reach `http://localhost:8080` — **their own machine**, which has nothing running there.

**Fix**: Make `KEYCLOAK_URL` a Vite environment variable. Build with the real domain baked in for production.

---

## Part 2 — What is a domain and how DNS works

A domain name (like `vault-app.duckdns.org`) is a human-readable alias for an IP address.

```
vault-app.duckdns.org  →  DNS lookup  →  123.45.67.89  →  your VM
```

**DNS (Domain Name System)** is the internet's phone book. When you type a domain in the browser:
1. Browser asks a DNS resolver: "What IP is `vault-app.duckdns.org`?"
2. DNS resolver checks the authoritative DNS server for `.duckdns.org`
3. DuckDNS returns the IP you configured
4. Browser connects to that IP

**DuckDNS** is a free service that gives you a subdomain (`*.duckdns.org`) pointing to any IP you set. You update the IP via their website or API. This is called a **dynamic DNS** service — useful when your VM's IP might change.

**TTL (Time to Live)**: DNS records have a TTL in seconds. If TTL is 300, DNS resolvers cache the result for 5 minutes. Changes take effect after the TTL expires.

---

## Part 3 — What is HTTPS and why it's mandatory

**HTTP** sends everything in plain text. Anyone between the user and server (ISP, Wi-Fi operator, router) can read the content, including JWT tokens.

**HTTPS** = HTTP + **TLS** (Transport Layer Security). TLS encrypts the connection so only the client and server can read the data. The `https://` prefix means TLS is active.

Why HTTPS is mandatory for this app:
- JWTs travel in HTTP headers → without HTTPS, anyone on the network can steal them and impersonate the user
- Keycloak's OAuth 2.0 redirect sends the `?code=` in the URL → must be encrypted
- Modern browsers block OAuth redirects to `http://` origins (not marked as secure)
- Let's Encrypt is free → there's no reason NOT to use HTTPS

---

## Part 4 — How Let's Encrypt works

**Let's Encrypt** is a free, automated Certificate Authority (CA). It issues TLS certificates at no cost.

A **TLS certificate** proves to the browser that:
1. The server is really who it claims to be (domain verification)
2. The connection is encrypted

**How the ACME protocol works** (what Certbot does automatically):

```
1. You run: certbot certonly -d vault-app.duckdns.org

2. Certbot asks Let's Encrypt: "I want a cert for vault-app.duckdns.org"

3. Let's Encrypt says: "Prove you control that domain.
   Serve this random token at http://vault-app.duckdns.org/.well-known/acme-challenge/TOKEN"

4. Certbot temporarily runs a small web server on port 80 to serve the token

5. Let's Encrypt fetches http://vault-app.duckdns.org/.well-known/acme-challenge/TOKEN
   If it matches → domain ownership proven

6. Let's Encrypt issues the certificate (valid for 90 days)

7. Certbot saves:
   /etc/letsencrypt/live/vault-app.duckdns.org/fullchain.pem  ← certificate
   /etc/letsencrypt/live/vault-app.duckdns.org/privkey.pem    ← private key
```

**Why 90 days?** To force automation. Short-lived certs are more secure because if a key is compromised, it expires soon anyway. Certbot sets up a systemd timer that auto-renews before expiry.

---

## Part 5 — What is `KC_PROXY: edge`

Keycloak runs inside Docker on HTTP (port 8080). Nginx sits in front of it and terminates TLS — meaning nginx receives HTTPS from the browser, decrypts it, and forwards plain HTTP to Keycloak internally.

```
Browser → HTTPS → Nginx → HTTP → Keycloak
```

The problem: Keycloak doesn't know it's behind nginx. It thinks it's being accessed over HTTP, so it builds redirect URLs like `http://vault-app.duckdns.org/realms/vault/...` instead of `https://...`.

`KC_PROXY: edge` tells Keycloak:
> "You're behind a reverse proxy that terminates TLS. Trust the `X-Forwarded-Proto` header that nginx sends, and use `https://` in all your URLs."

Without this, OAuth redirects and token `iss` claims will have `http://` instead of `https://`, breaking the whole login flow.

---

## Part 6 — Environment-specific config

The same codebase needs different values in different environments:

| Setting | Local dev | Production |
|---|---|---|
| `KEYCLOAK_URL` | `http://localhost:8080` | `https://vault-app.duckdns.org` |
| `KC_HOSTNAME` | `localhost` | `vault-app.duckdns.org` |
| Redirect URI | `http://localhost` | `https://vault-app.duckdns.org` |

Vite (the frontend build tool) handles this with `.env` files:

```
vault/frontend/.env               ← local dev values (gitignored)
vault/frontend/.env.production    ← production values (baked in at build time)
vault/frontend/.env.example       ← template committed to git
```

When you run `npm run build`, Vite reads `.env.production` and bakes the values into the compiled JS. So `import.meta.env.VITE_KEYCLOAK_URL` becomes the production URL in the production build.

The **backend** uses Docker's `env_file` + the VM's actual `.env` file (which you create on the VM from `.env.example`). Secrets like DB passwords never go in the repo.

---

## Summary — what changes and why

| What | Where | Why |
|---|---|---|
| `KC_HOSTNAME` | docker-compose.yml | Keycloak builds URLs with the hostname — must be the real domain |
| `KC_PROXY: edge` | docker-compose.yml | Keycloak is behind nginx TLS termination — needs to know |
| `redirectUris` | realm-export.json | Keycloak only redirects to allowed URIs after login |
| `webOrigins` | realm-export.json | Controls which origins Keycloak accepts tokens from |
| Consumer `key` | kong.yml | Must match JWT `iss` claim exactly |
| CORS `origins` | kong.yml | Browser blocks requests from unlisted origins |
| `KEYCLOAK_URL` | keycloak.js | Frontend must reach Keycloak at the real domain |
| nginx HTTPS block | nginx.conf | Serve on port 443 with TLS cert, redirect port 80 |
