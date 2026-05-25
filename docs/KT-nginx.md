# KT — Nginx: Zero to Hero Guide

---

## What is Nginx?

Nginx (pronounced "engine-x") is a web server. But calling it just a "web server" undersells it — it is also a reverse proxy, a load balancer, and a static file server, all in one.

It was created in 2004 by Igor Sysoev to solve a specific problem: the C10K problem — how to handle 10,000 concurrent connections on a single server. At the time, Apache (the dominant web server) struggled with this because it created one thread or process per connection. Nginx used an event-driven, non-blocking architecture instead — one worker process handles thousands of connections simultaneously.

Today Nginx powers over 30% of all websites on the internet including Netflix, Dropbox, Airbnb, and WordPress.com.

---

## The Problem Nginx Solves — Why We Need It

Without Nginx, our architecture looks like this:

```
Browser → http://yourdomain.com:8000 → FastAPI (uvicorn)
Browser → http://yourdomain.com:5173 → Vite dev server (NOT for production)
```

Problems with this:

**Problem 1 — Users should not type port numbers**
Nobody visits `yourdomain.com:8000`. They visit `yourdomain.com`. Port 80 (HTTP) and 443 (HTTPS) are the standard ports. Your FastAPI app cannot run on port 80 without root privileges (Linux restricts ports below 1024). Nginx runs on port 80/443 and forwards traffic to your app on port 8000.

**Problem 2 — The frontend has no server in production**
`npm run dev` is a development tool — you cannot run it in production. After `npm run build`, you have a `dist/` folder full of static files. You need something to serve those files. Nginx is exceptionally good at serving static files — much faster than FastAPI could.

**Problem 3 — CORS and multiple origins**
Right now the browser hits `localhost:8000` for the API and `localhost:5173` for the frontend — two different origins, causing CORS issues. With Nginx, everything comes from the same origin (`yourdomain.com`). Nginx routes internally:
- `yourdomain.com/` → serve frontend static files
- `yourdomain.com/api/` → forward to FastAPI

The browser sees one origin. CORS problem disappears.

**Problem 4 — SSL/TLS (HTTPS)**
Your FastAPI app does not handle SSL certificates. Nginx does. It terminates SSL — meaning it handles the encryption/decryption with the browser, then forwards plain HTTP internally to your app. Your app code never needs to know about certificates.

**Problem 5 — No protection against bad requests**
Uvicorn is an ASGI server designed for Python apps — not for dealing with the raw internet. Nginx acts as a shield: it handles slow clients, large request buffers, bad headers, and basic rate limiting before anything reaches your app.

---

## What is a Reverse Proxy?

This is the most important concept to understand about Nginx.

**Forward proxy:** You → Proxy → Internet
A forward proxy sits in front of clients. The internet sees the proxy's IP, not yours. VPNs work this way.

**Reverse proxy:** Client → Proxy → Your servers
A reverse proxy sits in front of your servers. The client sees the proxy's IP, not your server's IP. The client has no idea how many servers are behind it or what technology they use.

```
Without reverse proxy:
Browser ──────────────────────────────→ FastAPI :8000

With reverse proxy:
Browser → Nginx :80 → FastAPI :8000
                  ↘→ Static files (React dist/)
```

Nginx is the single public face of your application. Everything goes through it.

---

## What Nginx Does in Our Architecture

```
Internet
    ↓
[Nginx container] :80 / :443
    ├── GET /          → serve frontend/dist/index.html
    ├── GET /assets/*  → serve frontend/dist/assets/ (JS, CSS files)
    └── ANY /api/*     → forward to [api container] :8000
                                          ↓
                                   [db container] :5432
```

One domain. One port. Nginx decides where each request goes based on the URL path.

---

## Core Nginx Concepts

### nginx.conf — the configuration file

Everything Nginx does is controlled by `nginx.conf`. The structure:

```nginx
# global settings (worker processes, logging)

events {
    # connection handling settings
    worker_connections 1024;
}

http {
    # all HTTP-related configuration lives here

    server {
        # one server block = one virtual host

        listen 80;
        server_name yourdomain.com;

        location / {
            # what to do with requests matching this path
        }

        location /api/ {
            # what to do with /api/* requests
        }
    }
}
```

### server block

A `server` block defines a virtual host — a domain and port Nginx listens on. You can have multiple `server` blocks to host multiple websites on one machine.

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    ...
}
```

### location block

A `location` block defines what to do with requests matching a URL pattern. This is where routing happens.

```nginx
# exact match
location = /health {
    ...
}

# prefix match (anything starting with /api/)
location /api/ {
    ...
}

# regex match
location ~* \.(jpg|png|gif)$ {
    ...
}
```

### Serving static files

```nginx
location / {
    root /usr/share/nginx/html;   # where the files are on disk
    index index.html;             # default file to serve
    try_files $uri $uri/ /index.html;
    # try_files: look for the exact file → then as directory → fall back to index.html
    # the fallback to index.html is critical for React Router (client-side routing)
}
```

The `try_files` line is important for React. When a user visits `/notes`, there is no `notes.html` file on disk — that route is handled by React in the browser. The fallback to `index.html` loads React, which then handles the `/notes` route itself.

### Reverse proxy (forwarding to FastAPI)

```nginx
location /api/ {
    proxy_pass http://api:8000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

- `proxy_pass` — forward the request to this address
- `proxy_set_header Host` — tell the backend what domain the original request was for
- `proxy_set_header X-Real-IP` — tell the backend the client's real IP address (otherwise your app sees Nginx's IP for every request)
- `X-Forwarded-For` — standard header that carries the chain of proxies the request passed through

### Worker processes

```nginx
worker_processes auto;  # one worker per CPU core
```

Each Nginx worker handles thousands of connections simultaneously using non-blocking I/O. This is why Nginx is so efficient — it does not create a thread per connection like Apache.

---

## Nginx vs Apache — Why Nginx Won

| | Nginx | Apache |
|---|---|---|
| Architecture | Event-driven, non-blocking | Process/thread per connection |
| Memory usage | Low and predictable | Grows with connections |
| Static files | Extremely fast | Slower |
| Config style | Simple, hierarchical | Flexible but complex |
| Modules | Compiled in | Loadable at runtime |
| Best for | High traffic, static files, reverse proxy | Dynamic content, .htaccess per-directory config |

For a containerized microservices setup like ours, Nginx is the clear choice.

---

## Common Nginx Use Cases

| Use case | How |
|---|---|
| Serve static website | `root` + `index` directives |
| Reverse proxy to Node/Python | `proxy_pass` directive |
| Load balancer across multiple servers | `upstream` block |
| SSL termination | `listen 443 ssl` + certificate paths |
| Redirect HTTP to HTTPS | `return 301 https://` |
| Rate limiting | `limit_req_zone` directive |
| Gzip compression | `gzip on` directive |
| Cache static assets | `expires` directive |

---

## Where to Learn More — Reference Links

### Official
- **Nginx Beginner's Guide**: https://nginx.org/en/docs/beginners_guide.html
  Start here. Covers the basics of config, serving files, and proxy.

- **Nginx Full Documentation**: https://nginx.org/en/docs/
  Reference for every directive.

### Practical guides
- **DigitalOcean — Understanding Nginx Server and Location Block Selection**: https://www.digitalocean.com/community/tutorials/understanding-nginx-server-and-location-block-selection-algorithms
  The best explanation of how Nginx picks which block to use.

- **DigitalOcean — Nginx Configuration Guide**: https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-as-a-reverse-proxy-on-ubuntu-22-04
  Step by step reverse proxy setup.

### Videos
- **TechWorld with Nana — Nginx Crash Course** (YouTube): search "Nana Nginx" — she explains it visually with good diagrams, similar teaching style to what we follow here.

### Book
- **Nginx Cookbook** by Derek DeJonghe (O'Reilly) — if you want deep knowledge. Covers everything from basics to advanced load balancing and security.

---

## How This Fits Into Our Project

Right now (Phase 6):
```
Browser → localhost:8000 → FastAPI (Docker)
Browser → localhost:5173 → Vite dev server (local, not Docker)
```

After Phase 7:
```
Browser → localhost:80 → Nginx (Docker)
                            ├── / → React dist/ files (inside Nginx container)
                            └── /api/ → FastAPI container :8000
```

Everything through one door. One port. One container handling all external traffic.
