# KT — Kong API Gateway

---

## What is Kong?

Kong is an API Gateway. It sits in front of your backend services and acts as the single entry point for all API traffic — but it does far more than Nginx does.

Kong is built on top of Nginx. So everything Nginx does (reverse proxy, static file serving), Kong can do too. But Kong adds a plugin system on top — rate limiting, authentication, logging, request transformation, and much more — all without touching your application code.

Think of it this way:

```
Nginx   = a smart traffic director
Kong    = a smart traffic director with a security checkpoint,
          a toll booth, a visitor log, and an ID scanner
```

---

## Why We Need It — What Problem It Solves

Right now our architecture looks like this:

```
Browser → Nginx → FastAPI
```

Nginx routes traffic. FastAPI handles everything else — authentication, rate limiting, logging, CORS. Your application code is responsible for all of it.

As the application grows, this becomes a problem:

**Problem 1 — Every service reinvents the wheel**
If you add a second service (e.g., a notification service), it needs its own auth, its own rate limiting, its own logging. You write the same logic twice. Then three times. Then ten times.

**Problem 2 — Auth logic is scattered**
JWT verification lives inside FastAPI. If you want to add a mobile app, a third-party integration, or a partner API — each one needs its own auth handling in the application code.

**Problem 3 — No central control point**
To change rate limits, you redeploy the app. To add logging for all endpoints, you modify every route handler. There is no single place to apply cross-cutting concerns.

**Kong solves all three** by moving these concerns OUT of your application and into the gateway:

```
Browser → Kong (auth, rate limiting, logging, CORS) → FastAPI (only business logic)
```

FastAPI now only does what it should — business logic. Kong handles everything else.

---

## How Kong Fits Into Our Architecture

Before Kong:
```
Browser → Nginx :80
              ├── /          → React (static files)
              └── /api/*     → FastAPI :8000
```

After Kong:
```
Browser → Nginx :80
              ├── /          → React (static files)
              └── /api/*     → Kong :8001
                                    └── FastAPI :8000
```

Kong sits between Nginx and FastAPI. Every API request goes through Kong's plugin pipeline before reaching FastAPI.

---

## Core Concepts

### Service

A Service in Kong represents your upstream API — the backend it forwards requests to. In our case, one Service points to FastAPI.

```
Kong Service: vault-api
    upstream URL: http://api:8000
```

Think of a Service as Kong's name for "where to send the request."

### Route

A Route defines what incoming requests should be forwarded to a Service. It matches requests by URL path, HTTP method, host, or headers.

```
Kong Route: vault-api-route
    path: /api/
    strip_path: true          ← removes /api/ before forwarding to FastAPI
    service: vault-api
```

Think of a Route as "which requests trigger this Service."

One Service can have multiple Routes. Example:
```
Route 1: path /api/v1/ → Service: vault-api-v1
Route 2: path /api/v2/ → Service: vault-api-v2
```

### Plugin

A Plugin is a piece of functionality attached to a Route, a Service, or globally to all traffic. Plugins are Kong's superpower.

```
Plugin: rate-limiting
    attached to: vault-api-route
    config: 100 requests per minute per IP

Plugin: jwt
    attached to: vault-api-route
    config: verify JWT before forwarding

Plugin: file-log
    attached to: globally
    config: log all requests to a file
```

Plugins run in a pipeline — each plugin processes the request before passing it to the next one, and processes the response on the way back.

### Consumer

A Consumer represents a client that uses your API — a user, an app, a third-party integration. Consumers can have credentials (API keys, JWT tokens) attached to them.

```
Consumer: mobile-app
    credential: API key abc123

Consumer: partner-integration
    credential: API key xyz789
```

This lets you apply different rate limits or permissions to different clients.

### Admin API

Kong exposes a REST API on port 8001 to configure everything — Services, Routes, Plugins, Consumers. Instead of editing a config file and restarting, you call the Admin API and changes take effect immediately.

```bash
# create a service
curl -X POST http://localhost:8001/services \
  -d name=vault-api \
  -d url=http://api:8000

# create a route
curl -X POST http://localhost:8001/services/vault-api/routes \
  -d paths[]=/api/
```

This is how Kong is configured — not by editing YAML files but by calling its API. In production, tools like Helm or Terraform call this API to configure Kong declaratively.

---

## Most Useful Plugins

| Plugin | What it does |
|---|---|
| `rate-limiting` | Limit requests per second/minute/hour per IP or consumer |
| `jwt` | Verify JWT tokens before forwarding — FastAPI no longer needs to |
| `key-auth` | Require an API key header |
| `cors` | Handle CORS headers centrally — remove from FastAPI |
| `request-size-limiting` | Reject requests larger than X MB |
| `ip-restriction` | Allow or block specific IP ranges |
| `file-log` | Log all requests/responses to a file |
| `http-log` | Send logs to an HTTP endpoint (Elasticsearch, Datadog) |
| `response-transformer` | Add, remove, or rename headers in responses |
| `request-transformer` | Modify request headers or body before forwarding |
| `proxy-cache` | Cache responses — repeated identical requests served from cache |

All of these work without touching a single line of FastAPI code.

---

## Kong vs Nginx — Why Both?

You might wonder — if Kong is built on Nginx, why run both?

| Responsibility | Handled by |
|---|---|
| Serve React static files | Nginx |
| SSL termination | Nginx |
| Route `/api/*` to Kong | Nginx |
| Rate limiting | Kong |
| JWT verification | Kong |
| Logging | Kong |
| Forward to FastAPI | Kong |

Nginx handles the public-facing concerns (static files, SSL). Kong handles API management. They are complementary, not redundant.

In production at large companies, you often see:
```
Internet → CDN → Load Balancer → Nginx → Kong → Microservices
```

Each layer has a specific responsibility.

---

## Kong Deployment Modes

### DB mode
Kong stores its configuration (Services, Routes, Plugins) in a PostgreSQL or Cassandra database. The Admin API reads/writes from that database. Multiple Kong nodes share the same config through the database. Used in production clusters.

### DB-less mode (declarative)
Kong reads all configuration from a single YAML file (`kong.yml`) at startup. No database needed. Simpler to run, easier to version control. Changes require restarting Kong. Good for development and small deployments.

**We will use DB-less mode** — it is simpler, the config lives in a file we can commit to git, and we don't need to manage a separate Kong database.

---

## What Our kong.yml Will Look Like

```yaml
_format_version: "3.0"

services:
  - name: vault-api
    url: http://api:8000
    routes:
      - name: vault-api-route
        paths:
          - /api/
        strip_path: true

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
      headers:
        - Authorization
        - Content-Type
```

Everything Kong needs to know, in one file, version controlled.

---

## Reference Links

- **Kong Official Docs**: https://docs.konghq.com/gateway/latest/
- **Kong DB-less mode**: https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/
- **Kong Plugin Hub**: https://docs.konghq.com/hub/ — full list of all available plugins
- **Kong for Beginners (YouTube)**: search "Kong API Gateway tutorial" — Kong Inc. has an official YouTube channel with good walkthroughs

---

## Summary

| Concept | What it is |
|---|---|
| Service | Kong's name for the upstream backend (FastAPI) |
| Route | URL pattern that triggers forwarding to a Service |
| Plugin | Feature attached to a Route/Service (rate limiting, auth, logging) |
| Consumer | A client identity with credentials |
| Admin API | REST API on port 8001 to configure Kong |
| DB-less mode | Config from a YAML file, no database needed |
