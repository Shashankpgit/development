# Phase 8 — Step 1: Kong API Gateway

## What this step covers
Replace Nginx as the API-facing layer with Kong API Gateway. Kong handles routing, rate limiting, authentication plugins, logging, and more — features that would otherwise live in application code.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/015-kong-plan.md` first
- [ ] Explain the difference between a reverse proxy (Nginx) and an API gateway (Kong)
- [ ] Explain why you'd add Kong ON TOP OF or INSTEAD OF Nginx, not alongside randomly

---

## Why this step exists

Nginx is an excellent web server and reverse proxy. But it doesn't understand API concepts:
- It can't rate-limit per API key
- It can't do JWT verification without custom Lua scripts
- It can't generate per-consumer analytics
- It has no plugin ecosystem for API-specific concerns

Kong is built specifically for API management. Real companies (Airbnb, Nasdaq, etc.) use API gateways for:
- Rate limiting per consumer
- Authentication (JWT, OAuth, API keys)
- Request transformation
- Analytics and observability
- Blue-green deployments at the API level

---

## Architecture in this phase

```
Client
  ↓
Kong (port 80) — API gateway layer
  ↓
Nginx (internal, optional) — static file serving
  ↓
FastAPI (internal)
  ↓
PostgreSQL (internal)
```

Or simplified: Kong replaces Nginx for API routing, Nginx continues serving static files.

---

## What to implement

### Kong setup via docker-compose
- Add `kong` and `kong-db` services (Kong uses PostgreSQL for its own config)
- Run Kong migrations: `kong migrations bootstrap`
- Kong Admin API on port 8001 (internal only)
- Kong Proxy on port 80 (public)

### Configure Kong routes (via Kong Admin API)
- Service: `vault-api` pointing to FastAPI container
- Route: `/api/` → vault-api service
- Plugin: Rate Limiting (e.g., 100 requests per minute per IP)
- Plugin: Request logging

### Declarative config option
Use `kong.yml` (deck/declarative config) so Kong config is version-controlled:
```yaml
services:
  - name: vault-api
    url: http://api:8000
    routes:
      - name: vault-route
        paths: ["/api"]
plugins:
  - name: rate-limiting
    config:
      minute: 100
```

---

## Concepts to teach during this step

- **API Gateway vs Reverse Proxy**:
  - Reverse proxy: routes requests to backends (Nginx, HAProxy)
  - API Gateway: routes + understands API semantics (auth, rate limiting, versioning, analytics)

- **Kong's architecture**: Kong sits in front of your API and enforces policies. Your API code doesn't need to implement rate limiting — Kong does it.

- **Kong plugins**: The power of Kong is its plugin system. Enable rate-limiting, JWT auth, CORS, logging — all via config, no code changes in your app.

- **Kong Admin API**: Kong is configured via REST API (port 8001). This is also how tools like `deck` (declarative config) work.

- **Declarative vs imperative config**: Imperative = call `POST /services` to create a service. Declarative = define the desired state in `kong.yml`, let Kong sync it. The second approach is version-controllable (GitOps).

- **Rate limiting**: Protects your API from abuse. `100 requests/minute per IP` means a single IP cannot flood your API.

---

## What NOT to do in this step

- Do NOT configure JWT authentication in Kong yet (use custom JWT in FastAPI for now, Keycloak replaces it in Phase 9)
- Do NOT remove FastAPI's internal auth middleware (Kong + app auth are complementary)
- Do NOT expose Kong Admin API publicly

---

## File changes

| File | Action |
|---|---|
| `docker-compose.yml` | Modify — add kong + kong-db services |
| `kong.yml` | Create — declarative Kong config |
| `nginx/nginx.conf` | Modify — static files only (API routing moves to Kong) |

---

## Success criteria

```bash
docker-compose up --build
# http://localhost/api/health → Kong → FastAPI → 200 OK
# X-RateLimit-* headers appear in responses (Kong rate-limit plugin active)
# Sending 101+ requests/min → 429 Too Many Requests from Kong
# curl http://localhost:8001/services → Kong Admin API shows vault-api service
```

Show in DevTools: response headers include `X-Kong-Upstream-Latency` and `X-Kong-Proxy-Latency` — Kong adds these automatically.
