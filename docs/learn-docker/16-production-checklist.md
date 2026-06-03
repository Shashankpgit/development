# 16 — Production Checklist & Real-World Patterns

Everything you've learned, assembled into a complete production setup. This file shows what a hardened, real-world Docker deployment looks like — then gives you the checklist to verify yours.

---

## The Reference Stack

We'll build the compose setup for a realistic web application:

```
Internet → Nginx (TLS termination, reverse proxy)
            ↓
         FastAPI app (Python)
         ↙          ↘
   PostgreSQL       Redis (cache/sessions)
```

---

## The Production Dockerfile

```dockerfile
# ─── Build Stage ────────────────────────────────────────────────
FROM python:3.11-slim AS builder

# Install build-time OS dependencies (for packages with C extensions)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependency install first (cache layer) — installs to /install prefix
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ─── Runtime Stage ──────────────────────────────────────────────
FROM python:3.11-slim

LABEL org.opencontainers.image.title="Vault API" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.source="https://github.com/myorg/vault"

# Runtime OS dependencies (no build tools)
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq5 curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN adduser --disabled-password --no-create-home --uid 1001 appuser

WORKDIR /app

# Copy installed packages from builder stage
COPY --from=builder /install /usr/local

# Copy application code
COPY --chown=appuser:appuser . .

# Runtime environment flags (non-secret, non-env-specific)
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Switch to non-root
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Exec form — uvicorn is PID 1, handles SIGTERM correctly
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
```

---

## The Production docker-compose.yml

```yaml
version: "3.9"

# ─── Services ───────────────────────────────────────────────────
services:

  # ── PostgreSQL ────────────────────────────────────────────────
  db:
    image: postgres:16-alpine   # alpine = smaller attack surface
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql:ro  # optional: init scripts
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
    networks:
      - data_tier
    # No ports: — db should not be reachable from outside Docker
    deploy:
      resources:
        limits:
          memory: 512M

  # ── Redis ─────────────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - data_tier
    deploy:
      resources:
        limits:
          memory: 256M

  # ── Application ───────────────────────────────────────────────
  api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    image: myregistry/vault-api:${APP_VERSION:-latest}
    restart: unless-stopped
    env_file:
      - ./backend/.env           # app-specific secrets
    environment:
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/0
      APP_ENV: production
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - app_tier
      - data_tier
    # No direct port exposure — nginx proxies to this
    cap_drop:
      - ALL
    read_only: true
    tmpfs:
      - /tmp
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'

  # ── Nginx ─────────────────────────────────────────────────────
  nginx:
    image: nginx:1.25-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/certs:/etc/nginx/certs:ro
      - nginx_cache:/var/cache/nginx   # nginx needs to write cache
    depends_on:
      - api
    networks:
      - app_tier
    deploy:
      resources:
        limits:
          memory: 128M

# ─── Volumes ────────────────────────────────────────────────────
volumes:
  postgres_data:
  redis_data:
  nginx_cache:

# ─── Networks ───────────────────────────────────────────────────
networks:
  app_tier:      # nginx ↔ api
  data_tier:     # api ↔ db, api ↔ redis
  # nginx cannot reach db or redis directly — they're on different networks
```

---

## The Development Override

```yaml
# docker-compose.override.yml — auto-loaded in development, ignored in production
version: "3.9"

services:
  api:
    build:
      context: ./backend
    volumes:
      - ./backend:/app     # live code reload
    command: ["uvicorn", "app.main:app", "--reload", "--host", "0.0.0.0", "--port", "8000"]
    read_only: false        # easier debugging in dev
    cap_drop: []            # all caps available in dev
    ports:
      - "8000:8000"         # direct access in dev (no nginx needed)

  db:
    ports:
      - "5432:5432"         # expose db for local DB GUI tools

  redis:
    ports:
      - "6379:6379"
```

Development:
```bash
docker compose up   # auto-loads base + override
```

Production:
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## The .env File

```bash
# .env (gitignored — never committed)

# App version for image tagging
APP_VERSION=v1.2.3

# Database
DB_USER=vault_user
DB_PASSWORD=a_strong_random_password_here
DB_NAME=vault

# Redis
REDIS_PASSWORD=another_strong_random_password

# JWT
SECRET_KEY=a_64_char_random_hex_string_for_jwt_signing
```

```bash
# .env.example (committed — placeholder for teammates)
APP_VERSION=local
DB_USER=vault_user
DB_PASSWORD=
DB_NAME=vault
REDIS_PASSWORD=
SECRET_KEY=
```

---

## The Backup Script

```bash
#!/bin/bash
# backup.sh — run daily via cron

BACKUP_DIR="/backups/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

# Dump PostgreSQL
docker exec vault_db_1 pg_dump -U vault_user vault \
  | gzip > "$BACKUP_DIR/postgres_$(date +%H%M).sql.gz"

# Backup Redis RDB file (redis saves to volume)
docker run --rm \
  -v redis_data:/source:ro \
  -v "$BACKUP_DIR":/backup \
  alpine \
  cp /source/dump.rdb /backup/redis_$(date +%H%M).rdb

echo "Backup complete: $BACKUP_DIR"

# Keep only last 7 days of backups
find /backups -maxdepth 1 -type d -mtime +7 -exec rm -rf {} +
```

---

## The CI/CD Pipeline

```yaml
# .github/workflows/docker.yml
name: Build and Push

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}     # v1.2.3 → 1.2.3
            type=semver,pattern={{major}}.{{minor}} # v1.2.3 → 1.2
            type=sha,prefix=sha-                # short git SHA

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha          # use GitHub Actions cache
          cache-to: type=gha,mode=max

      - name: Scan for vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ghcr.io/${{ github.repository }}:sha-${{ github.sha }}
          exit-code: '1'
          severity: 'HIGH,CRITICAL'
```

---

## Deployment Checklist

### Dockerfile
- [ ] Uses a specific version tag (not `latest`)
- [ ] Multi-stage build (build tools not in final image)
- [ ] `slim` or `alpine` base for runtime stage
- [ ] `PYTHONUNBUFFERED=1` (or equivalent for your language)
- [ ] No secrets in `ENV` instructions
- [ ] Non-root user (`USER` instruction)
- [ ] `chown` applied before `USER` switch
- [ ] `HEALTHCHECK` defined
- [ ] `CMD` uses exec form (array)
- [ ] Build context is minimal (`.dockerignore` in place)

### docker-compose.yml
- [ ] `restart: unless-stopped` on all services
- [ ] `healthcheck` on all stateful services (db, redis)
- [ ] `depends_on: condition: service_healthy` for services that need db/redis ready
- [ ] Named volumes declared for all stateful services
- [ ] Ports: only expose what's needed externally; internal services have no `ports:`
- [ ] `cap_drop: ALL` on app containers
- [ ] Resource limits (`memory`, `cpus`) on all services
- [ ] Custom networks that isolate service tiers

### Secrets
- [ ] `.env` is in `.gitignore`
- [ ] `.env` is in `.dockerignore`
- [ ] `.env.example` is committed with placeholder values
- [ ] No secrets hardcoded in any Dockerfile
- [ ] No secrets in docker-compose.yml (use `${VAR}` substitution from `.env`)

### Operations
- [ ] Image scanned with Trivy or Docker Scout before each deploy
- [ ] Backup script exists and is tested
- [ ] `docker compose down` is in your runbook (not `down -v`)
- [ ] Monitoring: `docker stats` or Prometheus + cAdvisor
- [ ] Log aggregation: logs go somewhere (not just `docker logs`)

---

## Quick Reference Cheat Sheet

### Daily Commands
```bash
docker compose up -d                    # start all services, detached
docker compose down                     # stop and remove containers
docker compose logs -f api             # follow api logs
docker compose exec api bash           # shell into api container
docker compose restart api             # restart one service
docker compose up --build api          # rebuild and restart one service
```

### Debugging
```bash
docker logs container -f --tail 100    # last 100 lines, streaming
docker exec -it container sh           # shell in running container
docker run --rm -it image sh           # shell in fresh container
docker inspect container               # full metadata
docker stats --no-stream               # one-time resource snapshot
docker system df                       # Docker disk usage
```

### Image Management
```bash
docker build -t myapp:1.0 .           # build
docker tag myapp:1.0 registry/myapp:1.0  # tag for registry
docker push registry/myapp:1.0        # push
docker pull registry/myapp:1.0        # pull
docker image history myapp:1.0        # see layers and sizes
docker image prune -a                 # remove unused images
```

### Volumes
```bash
docker volume ls                       # list volumes
docker volume inspect volname          # see where data lives
docker volume prune                   # delete unused volumes
docker compose down                    # volumes survive
docker compose down -v                 # volumes DELETED (careful!)
```

### Cleanup
```bash
docker system prune                    # remove stopped containers, unused networks, dangling images
docker system prune -a                 # also remove unused images
docker system prune -a --volumes       # also remove unused volumes (data loss!)
docker system df                       # check disk usage before pruning
```

---

## What Comes Next: Beyond Docker

Docker solves: packaging, running, and local multi-container orchestration.

Docker does NOT solve: running hundreds of containers across many servers, automatic failover, rolling deployments, autoscaling.

For that, you need **Kubernetes**:
- Kubernetes manages containers across a cluster of machines
- Runs your containers with desired state (if a container dies, it restarts it)
- Handles rolling deployments, scaling, service discovery, config management
- Everything you've learned about Docker images, containers, networking, and volumes applies — Kubernetes builds on top of these concepts

**Starting points:**
- [kubernetes.io/docs](https://kubernetes.io/docs/home/) — official documentation
- [Play with Kubernetes](https://labs.play-with-k8s.com) — free browser-based playground
- [k3s](https://k3s.io) — lightweight Kubernetes for learning on a single machine
- [Docker Desktop includes Kubernetes](https://docs.docker.com/desktop/kubernetes/) — single-node cluster for development

---

## Summary

You have now covered every major Docker concept:

| # | Topic | What you learned |
|---|---|---|
| 1 | What is Docker | Why it exists, VMs vs containers |
| 2 | Installation | Setup on Linux/Mac/Windows |
| 3 | Core Concepts | Images, containers, layers, daemon, registry |
| 4 | CLI Commands | Run, exec, logs, inspect, stats |
| 5 | Dockerfile | Every instruction, layer system |
| 6 | Build Context | .dockerignore, context size |
| 7 | Layer Cache | Cache mechanics, language-specific patterns |
| 8 | Volumes | Named volumes, bind mounts, tmpfs |
| 9 | Networking | Bridge, DNS, port publishing |
| 10 | Compose | Multi-container apps, all fields |
| 11 | Env Vars | Secrets, .env patterns, ENV vs ARG |
| 12 | Multi-Stage | Shrink images dramatically |
| 13 | Registry | Push, pull, tagging, scanning |
| 14 | Debugging | Logs, exec, inspect, exit codes |
| 15 | Security | Non-root, minimal images, capabilities |
| 16 | Production | Everything assembled |

The journey continues with Kubernetes, CI/CD pipelines, service meshes, and cloud-native deployment patterns — all building on this foundation.

---

## Reference Links

- [Docker documentation](https://docs.docker.com) — the authoritative source for everything
- [12-factor app methodology](https://12factor.net) — principles behind cloud-native app design
- [Kubernetes documentation](https://kubernetes.io/docs/home/) — the next step after Docker
- [Docker Compose specification](https://compose-spec.io) — the full compose file spec
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Play with Docker](https://labs.play-with-docker.com) — browser-based Docker playground
