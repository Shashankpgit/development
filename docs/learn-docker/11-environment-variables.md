# 11 — Environment Variables & Secrets

Configuration that changes between environments (dev, staging, production) — database URLs, API keys, ports, feature flags — should never be hardcoded in your code or baked into your Docker images. Environment variables are the standard way to inject this configuration at runtime.

---

## Why Not Hardcode Configuration?

Three reasons:

1. **Different environments need different values.** Your dev database is `localhost`. Your production database is `prod-db.example.com`. If hardcoded, you need different images for each environment. Bad.

2. **Secrets must never appear in source code.** A database password committed to git is a permanent security incident — git history doesn't forget.

3. **Images should be built once and deployed everywhere.** The 12-factor app principle: separate config from code. The same image should run in dev, CI, and prod — only the injected configuration differs.

---

## The Four Ways to Pass Variables to a Container

### 1. Dockerfile ENV (build-time + runtime)

```dockerfile
ENV PYTHONUNBUFFERED=1
ENV PORT=8000
ENV APP_ENV=production
```

These variables are baked into the image. They are available at runtime in every container started from this image.

**Use for:** Non-secret, non-environment-specific configuration that should always be set. Runtime behavior flags (like `PYTHONUNBUFFERED`). Values that are the same regardless of where the image is deployed.

**Never use for:** Passwords, API keys, connection strings — they'd be baked into the image and visible to anyone who pulls it.

### 2. docker run -e (runtime, per-run override)

```bash
docker run -e DATABASE_URL=postgresql://user:pass@localhost/db myimage
docker run -e APP_ENV=development -e PORT=9000 myimage
```

Overrides or adds environment variables when starting a container. Takes precedence over Dockerfile `ENV`.

**Use for:** Quick overrides, debugging, one-off commands.

### 3. docker run --env-file (runtime, from a file)

```bash
docker run --env-file ./backend/.env myimage
```

Reads a file of `KEY=VALUE` pairs and passes them all to the container. The file stays on the host — it is NOT copied into the image.

### 4. docker-compose environment: and env_file: (runtime, from compose)

```yaml
services:
  api:
    environment:
      APP_ENV: production
      PORT: "8000"
    env_file:
      - ./backend/.env
```

The compose-native way. `environment:` for inline values, `env_file:` for file-based injection.

---

## The .env File: Two Different Uses in Compose

This is a common confusion point. There are **two** entirely separate `.env` behaviors in docker compose:

### Auto-loaded .env for YAML variable substitution

Compose automatically reads `.env` from the same directory as `docker-compose.yml`. Variables in it are available for `${VAR}` substitution inside the compose YAML:

```bash
# .env (same directory as docker-compose.yml)
DB_USER=vault_user
DB_PASSWORD=supersecret
APP_PORT=8000
```

```yaml
# docker-compose.yml
services:
  db:
    environment:
      POSTGRES_USER: ${DB_USER}      # ← substituted from .env
      POSTGRES_PASSWORD: ${DB_PASSWORD}
  api:
    ports:
      - "${APP_PORT}:8000"
```

**These variables are used to compose the YAML. They are NOT automatically injected into the containers.**

### env_file: for container injection

```yaml
services:
  api:
    env_file:
      - ./backend/.env    # these ARE injected into the container
```

The `env_file:` field explicitly passes a file's variables into the container.

**Summary of the two behaviors:**

| Behavior | What it does |
|---|---|
| Auto-loaded `.env` in compose dir | Substitutes `${VAR}` in the YAML file |
| `env_file: ./path/.env` | Injects variables into the container at runtime |

These can be the same file or different files. Usually you want them to be the same file for consistency.

---

## ENV vs ARG — The Build-Time vs Runtime Distinction

Both `ENV` and `ARG` appear in Dockerfiles. They are often confused.

| | `ENV` | `ARG` |
|---|---|---|
| Available during `docker build` | ✅ | ✅ |
| Available at container runtime | ✅ | ❌ |
| Persists into the image | ✅ | ❌ |
| Visible in `docker inspect` | ✅ | ❌ |
| Visible in `docker image history` | ✅ | ⚠️ (as build arg, still insecure) |
| Overridable at runtime via `-e` | ✅ | ❌ |
| Overridable at build time via `--build-arg` | ❌ | ✅ |

```dockerfile
# ARG: parameterize the build — e.g., pick which Python version to use
ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim

# ENV: set runtime configuration
ENV PYTHONUNBUFFERED=1
ENV PORT=8000
```

```bash
docker build --build-arg PYTHON_VERSION=3.12 .   # override ARG
docker run -e PORT=9000 myimage                   # override ENV
```

---

## The Precedence Order

When the same variable is set in multiple places, which one wins?

```
Lowest priority                                        Highest priority
───────────────────────────────────────────────────────────────────────
Dockerfile ENV  →  compose environment:  →  compose env_file:  →  docker run -e
```

In practice, `docker run -e` always wins. This lets you override for debugging without changing files.

---

## What Variables Are Inside Your Container?

```bash
# See all environment variables the container has
docker exec mycontainer env

# Or from docker inspect
docker inspect mycontainer --format '{{.Config.Env}}'
```

---

## Secrets — Never Bake Them Into Images

**The rule:** Never put a secret in a Dockerfile `ENV` instruction, and never put a secret in a file that's `COPY`-ed into the image.

**Why it matters:**

Images are permanent. Even if you `RUN rm secret_file` after copying it, the file exists in the layer created by `COPY`. Anyone who runs `docker image history myimage` or extracts the layer can read it.

```dockerfile
# ❌ WRONG — password is now in every layer ever built from this image
ENV DB_PASSWORD=supersecret

# ❌ ALSO WRONG — even if you delete it, the previous layer has it
COPY .env /app/.env
RUN rm /app/.env
```

```dockerfile
# ✅ CORRECT — no secret in the image at all
# Pass at runtime via env_file or environment in compose
```

**How to pass secrets safely:**

```yaml
# docker-compose.yml
services:
  api:
    env_file:
      - ./backend/.env    # file lives on host, never in image
    # or:
    environment:
      DB_PASSWORD: ${DB_PASSWORD}   # value from host's .env file, not hardcoded
```

The `.env` file stays on the host. It is listed in `.gitignore` (never committed). It is listed in `.dockerignore` (never copied into an image).

---

## The .env File Best Practices

### File structure

```bash
# backend/.env
# ─── Database ───────────────
DB_HOST=localhost
DB_PORT=5432
DB_USER=vault_user
DB_PASSWORD=supersecret_password
DB_NAME=vault

# ─── App ────────────────────
SECRET_KEY=your-jwt-secret-here
APP_ENV=development
PORT=8000

# ─── External Services ──────
STRIPE_API_KEY=sk_test_...
SENDGRID_API_KEY=SG....
```

### .env.example — the committed placeholder

Commit a `.env.example` that shows all required variables with fake/empty values. New teammates copy it and fill in real values:

```bash
cp .env.example .env
# then edit .env with real values
```

```bash
# backend/.env.example
DB_HOST=localhost
DB_PORT=5432
DB_USER=vault_user
DB_PASSWORD=              ← teammate fills this in
DB_NAME=vault
SECRET_KEY=               ← teammate fills this in
APP_ENV=development
PORT=8000
```

`.env.example` is committed to git. `.env` is gitignored.

---

## Accessing Variables in Your Code

### Python

```python
import os

db_host = os.environ.get("DB_HOST", "localhost")  # with default
secret_key = os.environ["SECRET_KEY"]              # required — raises KeyError if missing
```

Using `python-dotenv` for local development (outside Docker):
```python
from dotenv import load_dotenv
load_dotenv()  # reads .env file — useful when running app directly, not in Docker
```

### Node.js

```javascript
const dbHost = process.env.DB_HOST || 'localhost';
const secretKey = process.env.SECRET_KEY;
if (!secretKey) throw new Error('SECRET_KEY is required');
```

Using `dotenv`:
```javascript
require('dotenv').config();
// or in ES modules:
import 'dotenv/config';
```

### Go

```go
import "os"
dbHost := os.Getenv("DB_HOST")
```

---

## Docker Secrets (Swarm/Kubernetes)

For production at scale, injecting secrets via environment variables has a weakness: they're visible in `docker inspect` and in process listings (`/proc/<pid>/environ`).

**Docker Secrets** (available in Docker Swarm) mounts secrets as files in `/run/secrets/`:

```yaml
# Docker Swarm only
services:
  api:
    secrets:
      - db_password

secrets:
  db_password:
    external: true
```

The secret is accessible at `/run/secrets/db_password` inside the container — never as an environment variable, never in process listings.

For Kubernetes, the equivalent is `Secret` objects mounted as volumes.

For single-server or docker-compose deployments, `env_file:` with a gitignored `.env` is the pragmatic approach.

---

## BuildKit Secrets (For Build-Time Secrets)

If you need a secret during the build (e.g., a private pip registry token), never put it in `ARG` (visible in `docker image history`). Use BuildKit secrets:

```dockerfile
# Dockerfile
RUN --mount=type=secret,id=pip_token \
    PIP_INDEX_URL=https://token:$(cat /run/secrets/pip_token)@private-registry/simple \
    pip install --no-cache-dir -r requirements.txt
```

```bash
docker build --secret id=pip_token,src=./pip_token.txt .
```

The secret is never stored in any layer. `docker image history` shows nothing.

---

## Summary

- Never hardcode secrets in Dockerfiles or images
- Use `env_file:` in compose to inject `.env` into containers at runtime
- The `.env` file in compose's directory is auto-loaded for YAML variable substitution — this is separate from `env_file:`
- `ENV` is build-time + runtime; `ARG` is build-time only
- Override priority: `docker run -e` > `env_file:` > `environment:` > Dockerfile `ENV`
- Commit `.env.example` with placeholder values; gitignore `.env`
- For build-time secrets, use BuildKit's `--mount=type=secret`

**Next:** [12 — Multi-Stage Builds](12-multi-stage-builds.md)

---

## Reference Links

- [Environment variables in Docker Compose](https://docs.docker.com/compose/environment-variables/)
- [Manage sensitive data with Docker secrets](https://docs.docker.com/engine/swarm/secrets/)
- [BuildKit secret mounts](https://docs.docker.com/build/building/secrets/)
- [12-factor app config principle](https://12factor.net/config)
