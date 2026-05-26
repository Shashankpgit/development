# Phase 6 — Docker Plan

## Part 1: What we are doing

We are containerizing the vault application. Right now the app only runs on your machine because it depends on your local Python, your local PostgreSQL, and your specific `.env` setup. Docker packages the app and everything it needs into a portable unit that runs identically on any machine.

### Files being created

| File | Purpose |
|---|---|
| `vault/backend/Dockerfile` | Instructions to build the backend image |
| `vault/backend/.dockerignore` | What NOT to copy into the image |
| `vault/docker-compose.yml` | Defines both services (backend + PostgreSQL) and wires them together |

### What is NOT in scope for this step

- Nginx (Phase 7)
- Frontend container (Phase 7 — Nginx will serve the built frontend)
- Pushing to Docker Hub or deploying to cloud
- Multi-stage builds or image size optimization

---

## Part 2: Concepts

### Image vs Container

An image is the blueprint — a snapshot of the filesystem with your code, Python, and all dependencies baked in. A container is a running instance of that image. Same relationship as a class and an object. `docker build` creates an image. `docker run` starts a container from it.

### Dockerfile

A text file with step-by-step instructions for building an image. Each instruction creates a layer. Layers are cached — if a layer hasn't changed, Docker reuses the cached version. This is why we copy `requirements.txt` and install deps *before* copying the rest of the code — requirements change rarely, code changes constantly. If you copy everything first, every code change invalidates the pip install cache.

```dockerfile
FROM python:3.11-slim        # start from an existing base image
WORKDIR /app                 # all commands run from here inside the container
COPY requirements.txt .      # copy only this file first
RUN pip install ...          # install deps (cached unless requirements.txt changed)
COPY . .                     # now copy the rest of the code
CMD [...]                    # what to run when the container starts
```

### docker-compose

Running `docker run` manually is fine for one container. When you need multiple containers that talk to each other (your app needs a database), you use docker-compose. A `docker-compose.yml` file defines all services, their configuration, which ports to expose, and which network they share.

### Container networking

Each container has its own network namespace. If your app container tries to connect to `localhost:5432`, it is looking inside *its own container* — not your host machine or the db container. In docker-compose, containers talk to each other using the **service name** as the hostname. So your `DATABASE_URL` inside Docker becomes:

```
postgresql://vault_user:vault_pass@db:5432/vault
```

`db` is the service name defined in `docker-compose.yml`. Docker's internal DNS resolves it to the db container's IP automatically.

### Why `localhost` works outside Docker but breaks inside

| Where the app runs | Where PostgreSQL runs | `localhost` resolves to |
|---|---|---|
| Your machine (local dev) | Your machine | Works — same machine |
| Docker container A | Docker container B | Broken — container A's own loopback, nothing on port 5432 |

This is one of the most common Docker mistakes. The fix is to use the service name (`db`) instead of `localhost` in `DATABASE_URL` when running inside Docker.

### `.dockerignore`

Same concept as `.gitignore` — tells Docker what not to copy into the image when it executes `COPY . .`. Critical entries:

| Entry | Why |
|---|---|
| `.env` | Secrets must never be baked into an image — anyone who pulls the image can read them |
| `.venv/` | You install fresh inside the container — copying the local venv would be wrong Python version and path |
| `__pycache__/` | Compiled bytecode tied to your local Python path — useless and wasteful inside the image |

### Volumes

Containers are ephemeral — delete a container and all data inside it is gone. For the PostgreSQL container, we mount a **volume** (a named storage area managed by Docker) into the container's data directory. The database files live in the volume, not inside the container. So you can stop, delete, and recreate the container and all your data is still there in the volume.

```yaml
volumes:
  postgres_data:              # declare the volume

services:
  db:
    volumes:
      - postgres_data:/var/lib/postgresql/data   # mount it into the container
```

### Environment variables in Docker

Your `.env` file is in `.dockerignore` — it does not get copied into the image. Instead, docker-compose reads the `.env` file on the **host** at startup and passes the variables into the container at runtime. The container never stores the secrets permanently — it just receives them when it starts.
