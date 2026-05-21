# Phase 6 — Step 1: Docker + docker-compose

## What this step covers
Containerize the application with Docker and define a multi-service environment with docker-compose. Also migrate from SQLite to PostgreSQL at this stage.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/013-docker-plan.md` first
- [ ] Teach Docker concepts BEFORE writing Dockerfile
- [ ] This is also the right moment to switch from SQLite to PostgreSQL

---

## Why this step exists

The application works locally. But "works on my machine" is not a delivery. Docker solves this by packaging the application and all its dependencies into a container — a portable unit that runs identically everywhere.

This phase also introduces PostgreSQL, which is required for production. SQLite works for one person on one machine; it cannot handle concurrent writes or horizontal scaling.

---

## What to implement

### `Dockerfile`
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### `docker-compose.yml`
Two services:
1. `api` — the FastAPI app (built from Dockerfile)
2. `db` — PostgreSQL (official image)

Environment variables passed from `.env` to containers.

### `.dockerignore`
Exclude: `.env`, `.venv/`, `__pycache__/`, `vault.db`, `*.pyc`

### PostgreSQL migration
- Update `DATABASE_URL` to `postgresql://user:pass@db:5432/vault`
- Note: `db` is the docker-compose service name — Docker's internal DNS resolves it
- `vault.db` file is no longer used inside Docker

### Health check update
Add `HEALTHCHECK` instruction to Dockerfile.

---

## Concepts to teach during this step

- **What is Docker**: A way to package an application + its runtime environment into a portable image. "Works on my machine" becomes "works everywhere."

- **Image vs Container**: Image = the blueprint (like a class). Container = a running instance (like an object). `docker run` creates a container from an image.

- **`Dockerfile`**: Instructions to build an image. Each line is a layer. Layers are cached — this is why `COPY requirements.txt` comes before `COPY .` (requirements change less often than code).

- **docker-compose**: Defines multiple containers that work together. Your app needs a database — compose defines both and connects them on a private network.

- **Port mapping**: `-p 8000:8000` — left is host port, right is container port. "The container has its own network; we punch a hole through to the host."

- **Environment variables in Docker**: `.env` file is NOT copied into the container (see .dockerignore). Variables are passed explicitly via `env_file` or `environment` in docker-compose.

- **Volume for PostgreSQL data**: Database data must be persisted to a volume — otherwise deleting the container deletes all data.

- **`db` hostname in DATABASE_URL**: Inside Docker's network, service names become hostnames. `db` in docker-compose → `db` in connection string.

- **Why SQLite fails in Docker**: SQLite uses file locking — multiple containers trying to write to the same `.db` file causes corruption. PostgreSQL handles concurrent access properly.

---

## Migration to PostgreSQL

Steps:
1. Add `psycopg2-binary` to requirements.txt
2. Update `.env.example` with PostgreSQL DATABASE_URL format
3. Update `docker-compose.yml` with `db` service
4. Run `docker-compose up` — PostgreSQL starts, tables are created via SQLAlchemy `create_all`
5. Later (Phase 5.5 ideally, or here): introduce Alembic for proper migrations

---

## What NOT to do in this step

- Do NOT optimize the Dockerfile (multi-stage builds are Phase 12)
- Do NOT add Nginx yet (Phase 7)
- Do NOT push to Docker Hub yet
- Do NOT deploy to cloud yet (after Phase 7 the app is cloud-ready)

---

## File changes

| File | Action |
|---|---|
| `Dockerfile` | Create |
| `docker-compose.yml` | Create |
| `.dockerignore` | Create |
| `requirements.txt` | Modify — add `psycopg2-binary` |
| `.env.example` | Modify — update DATABASE_URL for PostgreSQL |

---

## Success criteria

```bash
docker-compose up --build
# API at http://localhost:8000/health → {"status": "ok", "database": "connected"}
# PostgreSQL running in separate container
# All Phase 4 endpoints work (auth, notes, passwords)
# Data persists across docker-compose restart (volume mounted)
```

Show: `docker ps` → two containers running. `docker logs vault_api_1` → uvicorn startup logs.
