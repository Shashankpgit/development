# Phase 8 — Kong API Gateway Plan

## Part 1: What we are doing

We are inserting Kong API Gateway between Nginx and FastAPI. Kong will run in **DB-less mode** — its configuration lives in a single `kong.yml` file committed to git. No separate database for Kong.

### Files being created / modified

| File | Purpose |
|---|---|
| `vault/kong/kong.yml` | Kong declarative config — Services, Routes, Plugins |
| `vault/docker-compose.yml` | Updated — adds kong service |
| `vault/nginx/nginx.conf` | Updated — `/api/*` now routes to Kong, not directly to FastAPI |

### What changes

| Before Phase 8 | After Phase 8 |
|---|---|
| Nginx → FastAPI directly | Nginx → Kong → FastAPI |
| Rate limiting not implemented at gateway | Rate limiting Kong plugin (100 req/min per IP) |
| CORS handled in FastAPI middleware | CORS handled by Kong plugin |
| No central request logging at gateway | Kong logs all API requests |

### What is NOT in scope

- Kong DB mode (not needed — DB-less is sufficient for our use case)
- Kong Consumers (Phase 9 — when Keycloak gives each request an identity)
- JWT verification via Kong (still handled by FastAPI — Phase 9)
- Multiple upstream services

---

## Part 2: Architecture

Before:
```
Browser → Nginx :80
              ├── /       → React static files
              └── /api/*  → FastAPI :8000
```

After:
```
Browser → Nginx :80
              ├── /           → React static files
              └── /api/*      → Kong proxy :8000 (internal)
                                      └── FastAPI :8000 (internal)
```

**Port layout (no conflicts — each container has its own port namespace):**

| Container | Port | Who talks to it |
|---|---|---|
| `api` (FastAPI) | 8000 internal | Kong only |
| `kong` proxy | 8000 internal | Nginx only |
| `kong` Admin API | 8001 internal, read-only in DB-less | Query only |
| `nginx` | 80 → host:80 | Browser |

FastAPI stays on port 8000. Kong also uses 8000 internally — no conflict because they are different containers (`api:8000` vs `kong:8000`).

---

## Part 3: kong.yml structure

```yaml
_format_version: "3.0"

services:
  - name: vault-api
    url: http://api:8000
    routes:
      - name: vault-api-route
        paths:
          - /
        strip_path: false

plugins:
  - name: rate-limiting
    config:
      minute: 100
      policy: local

  - name: cors
    config:
      origins:
        - http://localhost
      methods:
        - GET
        - POST
        - PUT
        - DELETE
        - OPTIONS
      headers:
        - Authorization
        - Content-Type
      credentials: true
```

---

## Part 4: Steps

1. Create `vault/kong/kong.yml` — declarative config
2. Update `vault/docker-compose.yml` — add kong service
3. Update `vault/nginx/nginx.conf` — change `/api/` proxy_pass to Kong
4. Test: `docker compose up --build`

---

## Part 5: Concepts to cover

- DB-less mode: config from kong.yml, version-controlled, no extra database
- Kong's two ports: proxy (8000) and Admin API (8001 — read-only in DB-less)
- Service vs Route: service = where to send it, route = what URL pattern triggers it
- Plugins as a pipeline — every request through the matched route runs all attached plugins
- Consumer role (teach it, implement in Phase 9)
