# Phase 7 — Step 1: Nginx Reverse Proxy

## What this step covers
Add Nginx as a reverse proxy in front of the FastAPI application using docker-compose. The outside world talks to Nginx on port 80/443; Nginx forwards to the API internally.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/014-nginx-plan.md` first
- [ ] Explain what a reverse proxy is and why you'd use one even for a small application

---

## Why this step exists

FastAPI/uvicorn is an application server — it runs your code. It is not designed to:
- Handle SSL/TLS termination (HTTPS)
- Serve static files efficiently
- Handle thousands of concurrent connections
- Rate limit abusive clients
- Route `/api` and `/` to different services

Nginx does all of this. In production, no application server faces the public internet directly. There is always a reverse proxy in front.

---

## What to implement

### `nginx/nginx.conf`
```nginx
upstream api {
    server api:8000;
}

server {
    listen 80;
    
    location /api/ {
        proxy_pass http://api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    location / {
        root /usr/share/nginx/html;
        try_files $uri /index.html;
    }
}
```

### Update `docker-compose.yml`
Add `nginx` service:
- Image: `nginx:alpine`
- Port: `80:80` (host:container)
- Depends on: `api`
- Volume: mounts `nginx/nginx.conf` and `frontend/` directory

### Move static files into Nginx
Nginx serves the frontend HTML/CSS/JS directly. FastAPI no longer mounts StaticFiles.

### Update API prefix
All API routes move under `/api/` prefix (e.g., `/api/health`, `/api/notes`).
Update FastAPI `app.include_router(..., prefix="/api")`.

---

## Concepts to teach during this step

- **Reverse proxy**: A server that sits in front of application servers and forwards requests. "Reverse" = proxy for servers (vs forward proxy = proxy for clients).

- **Why Nginx in front of FastAPI**:
  - SSL termination: Nginx handles HTTPS, decrypts, passes plain HTTP to the app
  - Static files: Nginx serves HTML/CSS/JS without touching Python
  - Connection handling: Nginx handles 10,000 concurrent connections; uvicorn handles business logic
  - Single entry point: one port (80/443) for everything

- **`proxy_set_header X-Real-IP`**: Without this, your app thinks all requests come from Nginx's IP, not the real client. This matters for logging and rate limiting.

- **`upstream` block**: Nginx load balances across upstream servers. Today: one API container. Tomorrow: three API containers. The nginx.conf doesn't change.

- **`try_files $uri /index.html`**: This is the SPA (Single Page Application) pattern. Any URL that doesn't match a file falls back to `index.html` — the frontend router handles it. Note for when a real frontend framework is added.

- **Port 80 vs 443**: 80 is HTTP, 443 is HTTPS. We use 80 for local dev. Before cloud deployment, we'll add a TLS certificate (Let's Encrypt) and redirect HTTP → HTTPS.

---

## This is the cloud-deployment readiness checkpoint

After this phase, the application is structured like a real deployment:
- Nginx: public-facing, handles TLS, serves static files
- API: internal, not exposed directly
- PostgreSQL: internal, not exposed directly

The only thing missing is a real server and a domain.

---

## What NOT to do in this step

- Do NOT configure HTTPS yet (that happens when deploying to cloud)
- Do NOT add rate limiting yet
- Do NOT add caching yet
- Do NOT add Kong yet (Phase 8)

---

## File changes

| File | Action |
|---|---|
| `nginx/nginx.conf` | Create |
| `docker-compose.yml` | Modify — add nginx service |
| `app/main.py` | Modify — update router prefix to /api |
| `frontend/app.js` | Modify — update API base URL to /api |

---

## Success criteria

```bash
docker-compose up --build
# http://localhost → Nginx serves the frontend HTML
# http://localhost/api/health → Nginx proxies to FastAPI → 200 OK
# http://localhost:8000 → NOT accessible (or no longer mapped to host)
# docker logs shows nginx access log entries for each request
```

Show in DevTools Network tab: request to `localhost/api/notes` — the response headers should include `Server: nginx`.
