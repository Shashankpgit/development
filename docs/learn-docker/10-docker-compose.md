# 10 — Docker Compose

Running `docker run` manually works for one container. Your application is rarely one container. Docker Compose solves the problem of running, wiring, and managing multiple containers as a single unit.

---

## Why Compose Exists — The Problem It Solves

A typical web application needs at minimum:
1. The application container (your code)
2. A database container (PostgreSQL, MySQL)
3. Maybe a cache container (Redis)
4. Maybe a worker container

Running these manually with `docker run` means:
- Manually creating a shared network
- Starting in the right order (db before app)
- Passing environment variables to each
- Mounting volumes
- Remembering the exact commands every time
- Repeating this for every teammate

Docker Compose describes your entire multi-container application in one YAML file and starts everything with:
```bash
docker compose up
```

---

## What docker compose actually does

When you run `docker compose up`, Compose:
1. Reads `docker-compose.yml`
2. Creates a **user-defined bridge network** (`<project>_default`)
3. Starts services in dependency order
4. Passes environment variables
5. Mounts volumes
6. Maps ports

When you run `docker compose down`:
1. Stops all containers
2. Removes containers
3. Removes the network
4. **Volumes survive** (unless you add `-v`)

---

## The docker-compose.yml Structure

```yaml
version: "3.9"    # compose file format version

services:          # each container is a "service"
  api:
    ...
  db:
    ...

volumes:           # declare named volumes
  postgres_data:

networks:          # custom networks (optional — compose creates one automatically)
  backend_net:
```

---

## All Important Fields

### version

```yaml
version: "3.9"
```

Specifies the compose file format version. Use `3.9` or simply omit it (modern Compose V2 doesn't require it). The version determines which features are available.

---

### services

The core of the file. Each key under `services` becomes:
- A container name (prefixed with project name)
- A hostname resolvable by other services on the same network

```yaml
services:
  api:    # other containers reach this at "api"
  db:     # other containers reach this at "db"
```

---

### image vs build

```yaml
# Use a pre-built image from a registry
services:
  db:
    image: postgres:16

# Build from a Dockerfile
services:
  api:
    build:
      context: ./backend     # directory containing the Dockerfile
      dockerfile: Dockerfile  # optional if named "Dockerfile"
      args:
        BUILD_ENV: production  # pass build args
```

| | `image` | `build` |
|---|---|---|
| Source | Pull from registry | Build from local Dockerfile |
| Use for | Third-party (postgres, redis, nginx) | Your own code |
| Rebuilt automatically? | No | Only with `--build` flag |

---

### ports

```yaml
services:
  api:
    ports:
      - "8000:8000"          # host:container
      - "127.0.0.1:8000:8000" # bind to localhost only (safer)
```

Exposes a container port to the host. Without `ports:`, the service is only reachable from inside the Docker network.

**Only expose what you need.** PostgreSQL in most setups should NOT have `ports:` — it only needs to be reachable by the `api` container on the internal network, not by your host machine.

---

### environment

```yaml
services:
  db:
    environment:
      POSTGRES_USER: vault_user
      POSTGRES_PASSWORD: vault_pass
      POSTGRES_DB: vault
```

Sets environment variables inside the container. Two syntaxes:

```yaml
# Map style (key: value)
environment:
  MY_VAR: hello

# List style (VAR=value)
environment:
  - MY_VAR=hello

# Reference host env var (no value = take from host)
environment:
  - SECRET_KEY    # value comes from host environment variable SECRET_KEY
```

---

### env_file

```yaml
services:
  api:
    env_file:
      - ./backend/.env
      - ./common.env    # multiple files supported
```

Reads a `.env` file from the host and injects all its variables into the container at runtime. The `.env` file is NOT copied into the image — it's read by compose at startup.

| | `environment:` | `env_file:` |
|---|---|---|
| Values defined | Inline in YAML | External file |
| Good for | Non-secret config, third-party defaults | App secrets |
| Risk if committed | Values visible in compose file | File can be gitignored |

---

### volumes (per service)

```yaml
services:
  db:
    volumes:
      # Named volume
      - postgres_data:/var/lib/postgresql/data
      
      # Bind mount (host path:container path)
      - ./backend:/app
      
      # Read-only bind mount
      - ./config:/config:ro
```

See [08-volumes.md](08-volumes.md) for the full volume story.

---

### depends_on

```yaml
services:
  api:
    depends_on:
      - db    # start db before api
```

**CRITICAL GOTCHA:** `depends_on` only waits for the `db` **container to start** — NOT for PostgreSQL **inside the container to be ready**. PostgreSQL takes a few seconds to initialize. If `api` starts too quickly, it tries to connect before PostgreSQL is ready and crashes.

**The correct pattern:** Use healthchecks:

```yaml
services:
  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vault_user -d vault"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s   # grace period before checks begin

  api:
    build: ./backend
    depends_on:
      db:
        condition: service_healthy   # ← wait until healthcheck passes
```

Now `api` starts only after PostgreSQL reports healthy. This is the correct production pattern.

---

### healthcheck

```yaml
services:
  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vault_user -d vault"]
      interval: 5s       # check every 5 seconds
      timeout: 5s        # fail if no response within 5 seconds
      retries: 5         # mark unhealthy after 5 consecutive failures
      start_period: 10s  # wait 10 seconds before starting checks (slow startup grace)
```

Docker runs the `test` command inside the container. Exit code 0 = healthy, non-zero = unhealthy.

Common healthcheck commands:
```bash
# PostgreSQL
pg_isready -U myuser -d mydb

# HTTP endpoint
curl -f http://localhost:8000/health

# Redis
redis-cli ping

# MySQL
mysqladmin ping -h localhost
```

---

### restart

```yaml
services:
  api:
    restart: unless-stopped
```

| Value | Behavior |
|---|---|
| `no` | Never restart (default) |
| `always` | Always restart, even after `docker compose down` (and on system boot if Docker starts) |
| `on-failure` | Restart only if exit code is non-zero |
| `unless-stopped` | Restart always, unless you explicitly stopped it with `docker compose stop` |

**Recommendation:**
- `unless-stopped` for production/long-running services
- `no` or omit during development (you want to investigate failures, not auto-restart)

---

### networks (per service and top-level)

```yaml
networks:
  frontend_net:
  backend_net:

services:
  nginx:
    networks:
      - frontend_net
  api:
    networks:
      - frontend_net
      - backend_net
  db:
    networks:
      - backend_net    # db only reachable from api, not from nginx
```

If you don't define networks, compose creates a default network and puts all services on it. Custom networks give you isolation between service tiers.

---

### command and entrypoint

```yaml
services:
  api:
    command: ["uvicorn", "app.main:app", "--reload", "--host", "0.0.0.0"]
    # Overrides the CMD in the Dockerfile

    entrypoint: ["/docker-entrypoint.sh"]
    # Overrides the ENTRYPOINT in the Dockerfile
```

Useful for running the same image with different commands in different environments (dev uses `--reload`, production doesn't).

---

### container_name

```yaml
services:
  db:
    container_name: vault_postgres  # instead of vault_db_1
```

By default, compose names containers `<project>_<service>_<n>`. A custom name makes it easier to reference in scripts. But if you set `container_name`, you cannot scale that service (you can't have two containers with the same name).

---

### labels

```yaml
services:
  api:
    labels:
      - "com.example.version=1.0"
      - "com.example.environment=production"
```

Metadata attached to the container. Readable via `docker inspect`.

---

## The Full docker-compose.yml Example

A production-ready compose file for a FastAPI app + PostgreSQL + Redis:

```yaml
version: "3.9"

services:

  # ─── Database ───────────────────────────────────────────────
  db:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
    networks:
      - backend_net

  # ─── Cache ──────────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - backend_net

  # ─── Application ────────────────────────────────────────────
  api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    restart: unless-stopped
    env_file:
      - ./backend/.env          # secrets loaded from file
    environment:
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
      REDIS_URL: redis://redis:6379/0
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - "127.0.0.1:8000:8000"  # only localhost can reach it (nginx in front in prod)
    networks:
      - backend_net
      - frontend_net

  # ─── Reverse Proxy ──────────────────────────────────────────
  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - api
    networks:
      - frontend_net

# ─── Volumes ────────────────────────────────────────────────
volumes:
  postgres_data:

# ─── Networks ───────────────────────────────────────────────
networks:
  backend_net:     # api, db, redis — no internet-facing exposure
  frontend_net:    # api, nginx — internet-facing tier
```

---

## docker compose CLI Commands

```bash
# Start all services (attach mode — logs stream to terminal)
docker compose up

# Start detached (background)
docker compose up -d

# Rebuild images and start
docker compose up --build

# Stop and remove containers (volumes survive)
docker compose down

# Stop and remove containers + volumes (wipes database!)
docker compose down -v

# See running services
docker compose ps

# Stream logs from all services
docker compose logs -f

# Stream logs from one service
docker compose logs -f api

# Run a one-off command in a service container
docker compose exec api bash
docker compose exec db psql -U vault_user -d vault

# Restart a single service
docker compose restart api

# Rebuild a single service
docker compose build api

# Pull latest images for services using image:
docker compose pull

# See resource usage
docker compose top
```

---

## Override Files for Dev vs Prod

A powerful pattern: base file + environment-specific overrides.

**docker-compose.yml** (base — shared config):
```yaml
services:
  api:
    build: ./backend
    env_file: ./backend/.env
  db:
    image: postgres:16
    volumes:
      - postgres_data:/var/lib/postgresql/data
volumes:
  postgres_data:
```

**docker-compose.override.yml** (development additions — auto-loaded):
```yaml
services:
  api:
    volumes:
      - ./backend:/app          # live code reload
    command: ["uvicorn", "app.main:app", "--reload", "--host", "0.0.0.0"]
    ports:
      - "8000:8000"
  db:
    ports:
      - "5432:5432"             # expose db port for GUI tools
```

**docker-compose.prod.yml** (production):
```yaml
services:
  api:
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"
  db:
    restart: unless-stopped
```

Usage:
```bash
# Development: auto-loads docker-compose.yml + docker-compose.override.yml
docker compose up

# Production: explicit file selection
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## Compose Profiles

Mark optional services with a profile:

```yaml
services:
  api:
    image: myapp
  
  db:
    image: postgres:16
  
  pgadmin:
    image: dpage/pgadmin4
    profiles:
      - tools    # only starts when the "tools" profile is active
```

```bash
docker compose up                          # starts api and db only
docker compose --profile tools up          # starts api, db, and pgadmin
```

---

## The .env Auto-Loading Feature

Compose automatically reads a `.env` file in the same directory as `docker-compose.yml`. Variables in that file become available for **substitution inside the compose YAML** using `${VAR}` syntax.

```bash
# .env (same dir as docker-compose.yml)
DB_USER=vault_user
DB_PASSWORD=supersecret
DB_NAME=vault
APP_PORT=8000
```

```yaml
# docker-compose.yml
services:
  db:
    environment:
      POSTGRES_USER: ${DB_USER}        # ← substituted from .env
      POSTGRES_PASSWORD: ${DB_PASSWORD}
```

**This is different from `env_file:`** — the auto-loaded `.env` is for variable substitution in the compose YAML itself. `env_file:` passes variables into the container.

---

## Common Gotchas

### 1. `depends_on` doesn't wait for readiness
Only waits for container start, not service readiness. Use healthchecks with `condition: service_healthy`.

### 2. `down -v` deletes your database
The most dangerous compose command. Never run it carelessly.

### 3. Code changes don't auto-rebuild
`docker compose up` does not rebuild images. You need `--build` flag.

### 4. The `db` hostname only works inside Docker
`DATABASE_URL=...@db:5432/...` only resolves inside the Docker network. Running the app locally (outside Docker) requires `localhost` instead.

### 5. Port conflicts
If something on your host is already using port 8000, compose fails on start. Stop the local process first.

### 6. Multiple compose files and variable scope
When using `-f` flags with multiple compose files, variables from `.env` are applied to all of them.

---

## Summary

- Compose describes the full multi-container app in one YAML file
- Key fields: `image`/`build`, `ports`, `environment`, `env_file`, `volumes`, `depends_on`, `healthcheck`, `restart`
- `depends_on` alone is not enough — combine with `condition: service_healthy` and a `healthcheck`
- `docker compose down` preserves volumes; `docker compose down -v` deletes them
- Use override files to separate dev and production configuration
- Compose creates a user-defined bridge network automatically — services reach each other by service name

**Next:** [11 — Environment Variables & Secrets](11-environment-variables.md)

---

## Reference Links

- [Docker Compose overview](https://docs.docker.com/compose/)
- [Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Compose CLI reference](https://docs.docker.com/reference/cli/docker/compose/)
- [Compose profiles](https://docs.docker.com/compose/profiles/)
