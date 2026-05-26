# Phase 7 — Nginx Plan

## Part 1: What we are doing

We are adding Nginx as a reverse proxy and static file server in front of our application.

### Files being created

| File | Purpose |
|---|---|
| `vault/nginx/nginx.conf` | Nginx configuration — routing rules |
| `vault/nginx/Dockerfile` | Multi-stage build — builds React app, copies into Nginx image |
| `vault/docker-compose.yml` | Updated — adds nginx service |

### What changes

| Before Phase 7 | After Phase 7 |
|---|---|
| Browser hits FastAPI directly on port 8000 | Browser hits Nginx on port 80 |
| Frontend runs on Vite dev server (localhost:5173) | Frontend served by Nginx from built static files |
| Two origins (8000 + 5173) → CORS needed | Single origin (port 80) → CORS no longer needed |
| No SSL termination point | Nginx is the SSL termination point (Phase 7+) |

### What is NOT in scope

- SSL/HTTPS certificate (added when deploying to cloud)
- Kong API gateway (Phase 8)
- Load balancing across multiple backend instances

---

## Part 2: Concepts

### What we are building

```
Browser → Nginx :80
              ├── GET /           → serve React dist/index.html
              ├── GET /assets/*   → serve React dist/assets/ (JS, CSS)
              └── ANY /api/*      → proxy_pass to api container :8000
```

### Multi-stage Dockerfile

The Nginx Dockerfile has two stages:

Stage 1 — Builder (Node.js):
- Copy frontend source code
- Run npm install + npm run build
- Output: dist/ folder with compiled React app

Stage 2 — Final image (Nginx):
- Start from nginx:alpine
- Copy dist/ from Stage 1
- Copy nginx.conf
- Node.js is completely discarded — not in the final image

### nginx.conf structure

```
worker_processes        ← how many CPU cores to use
events {}               ← connection handling settings
http {
    server {
        listen 80       ← port to listen on
        location / {}   ← serve static React files
        location /api/ {} ← proxy to FastAPI
    }
}
```
