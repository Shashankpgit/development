# Phase 6 — Step 1: Docker + docker-compose

## What this step covers
Containerize the application with Docker and define a multi-service environment with docker-compose. The backend and PostgreSQL each get their own container.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/013-docker-plan.md` first
- [ ] Teach Docker concepts BEFORE writing Dockerfile

---

## Why this step exists

The application works locally. But "works on my machine" is not a delivery. Docker solves this by packaging the application and all its dependencies into a container — a portable unit that runs identically everywhere.

We already use PostgreSQL. In Docker, the database runs in its own container and the backend connects to it via Docker's internal network.

---

## What to implement

### `vault/backend/Dockerfile`
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### `vault/docker-compose.yml`
Two services:
1. `api` — the FastAPI backend (built from Dockerfile in `./backend`)
2. `db` — PostgreSQL (official image)

Environment variables passed from `.env` to containers.

### `vault/backend/.dockerignore`
Exclude: `.env`, `.venv/`, `__pycache__/`, `*.pyc`

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

- **`db` hostname in DATABASE_URL**: Inside Docker's network, service names become hostnames. `db` in docker-compose → `db` in connection string. The `DATABASE_URL` in `.env` uses `localhost` for local dev, but inside Docker it becomes `postgresql://user:pass@db:5432/vault`.

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
| `vault/backend/Dockerfile` | Create |
| `vault/docker-compose.yml` | Create |
| `vault/backend/.dockerignore` | Create |
| `vault/backend/.env.example` | Modify — add docker DATABASE_URL format comment |

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
