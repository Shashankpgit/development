# KT — Dockerfile Deep Dive

---

## What is a Dockerfile?

A Dockerfile is a plain text script that tells Docker how to build an image. Every line is an instruction. Docker executes them top to bottom, and each instruction that modifies the filesystem creates a **layer**. The final image is the stack of all those layers.

Think of it like a recipe: ingredients (base image), preparation steps (RUN commands), and the final dish (your image).

---

## The Layer System — The Most Important Concept

Before learning the commands, you need to understand layers — everything else depends on this.

Every `RUN`, `COPY`, and `ADD` instruction creates a new layer. A layer is a diff — it records only what changed compared to the previous layer. Layers are:

- **Cached** — if the instruction and its inputs haven't changed, Docker reuses the cached layer
- **Immutable** — once created, a layer never changes
- **Stacked** — the final image is layers stacked on top of each other

### Why order matters enormously

```dockerfile
# BAD — code changes bust the pip cache every time
COPY . .
RUN pip install -r requirements.txt

# GOOD — pip cache survives code changes
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

When you change a file in your project and rebuild:
- **Bad order**: Docker sees `COPY . .` changed → reruns pip install (slow, every time)
- **Good order**: Docker sees `requirements.txt` unchanged → reuses cached pip layer → only re-runs `COPY . .` (fast)

Rule: **put things that change rarely near the top, things that change often near the bottom.**

---

## All Commands — What They Do and When to Use Them

### FROM

```dockerfile
FROM python:3.11-slim
```

Every Dockerfile must start with `FROM`. It sets the base image — the starting point your image is built on top of. You are not building from scratch; you are standing on someone else's shoulders.

`python:3.11-slim` means: official Python 3.11 image, slim variant (stripped of unnecessary tools to keep the size small).

**Variants you'll see:**
| Tag | What it means |
|---|---|
| `python:3.11` | Full image — includes compilers, tools. Large (~900MB) |
| `python:3.11-slim` | Stripped down. No compilers. Smaller (~130MB) |
| `python:3.11-alpine` | Tiny (~50MB) but uses musl libc — some packages break |

**For our app:** `python:3.11-slim` is the right choice. Small enough, compatible with all our packages.

---

### WORKDIR

```dockerfile
WORKDIR /app
```

Sets the working directory inside the container for all subsequent instructions. If the directory doesn't exist, Docker creates it. Every `RUN`, `COPY`, `CMD` after this runs relative to `/app`.

Without `WORKDIR`, your files would end up scattered in the root `/` — messy and error-prone.

**Edge case:** You can have multiple `WORKDIR` instructions — each changes the directory from that point onwards.

---

### COPY

```dockerfile
COPY requirements.txt .
COPY . .
```

Copies files from the **build context** (your host machine) into the image.

- First argument: source path on host
- Second argument: destination path in image (`.` means current `WORKDIR`)

`COPY requirements.txt .` → copies `requirements.txt` from host into `/app/requirements.txt` in the image.

**What is the build context?** When you run `docker build`, Docker sends the entire directory (and its contents) to the Docker daemon. Only files inside that directory can be copied. Files listed in `.dockerignore` are excluded from the context before it's sent.

---

### ADD

```dockerfile
ADD archive.tar.gz /app/
ADD https://example.com/file.txt /app/
```

`ADD` does everything `COPY` does, plus two extras:
1. If source is a `.tar.gz`, `.zip`, etc. — it automatically extracts it
2. Source can be a URL — Docker fetches it

**When to use `ADD` vs `COPY`:**
- Use `COPY` for everything — it's explicit and predictable
- Use `ADD` only when you specifically need auto-extraction of archives
- Fetching URLs via `ADD` is considered bad practice — use `RUN curl` instead so the step is visible and cached properly

**Rule: default to `COPY`. Use `ADD` only for tar extraction.**

---

### RUN

```dockerfile
RUN pip install --no-cache-dir -r requirements.txt
RUN apt-get update && apt-get install -y curl
```

Executes a command **at build time** and commits the result as a new layer.

`RUN` is for setting things up: installing packages, creating directories, setting permissions.

**Important edge case — layer count:**

Each `RUN` creates a layer. More layers = larger image. Common pattern to reduce layers:

```dockerfile
# BAD — 3 layers
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get clean

# GOOD — 1 layer
RUN apt-get update && apt-get install -y curl && apt-get clean
```

The `&&` chains commands into one layer. The `\` allows splitting across lines for readability:

```dockerfile
RUN apt-get update \
    && apt-get install -y curl \
    && apt-get clean
```

**`--no-cache-dir` in pip:** Tells pip not to save downloaded packages to pip's own cache. Inside a Docker image, that cache would just waste space — you'll never reuse it.

---

### ENV

```dockerfile
ENV APP_ENV=production
ENV PYTHONUNBUFFERED=1
```

Sets environment variables that are available **both during build and when the container runs**.

`PYTHONUNBUFFERED=1` is a common Python setting — it forces Python to flush stdout/stderr immediately instead of buffering. Without it, your `print()` statements and logs might not appear in `docker logs` in real time.

**ENV vs ARG — the most confused pair:**

| | `ENV` | `ARG` |
|---|---|---|
| Available at build time | Yes | Yes |
| Available when container runs | Yes | No |
| Visible in `docker inspect` | Yes | No |
| Can be overridden at runtime | Yes (`-e` flag) | No |

`ARG` is for build-time configuration only (e.g., a version number you want to inject during build). `ENV` is for runtime configuration. **Never put secrets in either** — use docker-compose to inject them at runtime from `.env`.

---

### EXPOSE

```dockerfile
EXPOSE 8000
```

Documents that the container listens on port 8000. It does **not** actually publish or open the port — it is purely informational.

The actual port publishing happens in `docker-compose.yml` with `ports: - "8000:8000"` or in `docker run -p 8000:8000`.

**Why does it exist then?** It serves as documentation for anyone reading the Dockerfile, and tools like docker-compose can use it for automatic port detection in some modes.

**Common confusion:** Beginners add `EXPOSE` thinking it opens the port. It doesn't. You still need `-p` or `ports:` in compose.

---

### CMD

```dockerfile
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Defines the **default command** to run when a container starts. There can only be one `CMD` — if you write multiple, only the last one takes effect.

`CMD` can be **overridden** at runtime:
```bash
docker run myimage python3 some_script.py   # overrides CMD
```

**Shell form vs exec form — the other confused pair:**

```dockerfile
# Shell form — runs via /bin/sh -c
CMD uvicorn app.main:app --host 0.0.0.0

# Exec form — runs directly, no shell
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0"]
```

**Use exec form (the array).** Shell form spawns a shell process as PID 1, which doesn't forward signals properly. Exec form makes your process PID 1 directly — it receives `SIGTERM` cleanly when Docker stops the container, allowing graceful shutdown.

---

### ENTRYPOINT

```dockerfile
ENTRYPOINT ["uvicorn"]
CMD ["app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

`ENTRYPOINT` sets the fixed command that always runs. `CMD` then provides default arguments to it.

When used together: `ENTRYPOINT` + `CMD` = `uvicorn app.main:app --host 0.0.0.0 --port 8000`

The difference from `CMD` alone:

| | `CMD` | `ENTRYPOINT` |
|---|---|---|
| Can be overridden at runtime | Yes — `docker run img python3 x.py` | Hard — requires `--entrypoint` flag |
| Typical use | Default command for flexible images | Fixed command that always runs |

**For our app:** We use `CMD` alone. `ENTRYPOINT` makes more sense for tool images (like a CLI tool where the command is always the same).

---

### ARG

```dockerfile
ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim
```

Build-time variable. Only available during `docker build`, not when the container runs.

```bash
docker build --build-arg PYTHON_VERSION=3.12 .
```

Use `ARG` for things you want to parameterize at build time — like a version number. Never for secrets.

---

### HEALTHCHECK

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1
```

Tells Docker how to check if the container is healthy. Docker runs this command periodically. If it fails `--retries` times, the container is marked `unhealthy`.

Used by docker-compose to know when a service is ready (e.g., don't start the app until the database healthcheck passes).

---

### USER

```dockerfile
RUN adduser --disabled-password --no-create-home appuser
USER appuser
```

By default, everything inside a Docker container runs as **root** (uid 0) — the most powerful user that exists on any Linux system.

**Why that is a security risk:**

Imagine a bug in your app that lets an attacker run arbitrary commands (a real class of vulnerability). If your process is root inside the container, the attacker has root. If they find any way to escape the container (rare but has happened in real incidents), they land on the host machine as root. Full access to everything.

**What `USER` does:**

Creates a normal system user and switches all subsequent instructions — and the final `CMD` — to run as that user. If the attacker gets code execution, they are a low-privilege nobody with no write access to system files, no ability to install software, no path to escalation.

```dockerfile
# create a system user (no password, no home directory)
RUN adduser --disabled-password --no-create-home appuser

# everything after this runs as appuser, including CMD
USER appuser
```

**The file permission gotcha:**

When you `COPY . .` before `USER`, files are owned by root. Your `appuser` can read them but cannot write to them. For a read-only web app (uvicorn serving Python files) this is fine — reading is all it needs. But if your app writes files to disk (logs, uploads, temp files), you must `chown` those directories before switching:

```dockerfile
RUN adduser --disabled-password --no-create-home appuser \
    && chown -R appuser:appuser /app

USER appuser
```

The `&&` keeps it in one layer — no extra image size cost.

**Why we are not adding it in Phase 6:**

Our app writes nothing to disk — logs go to stdout, all data goes to PostgreSQL. So `USER` would work fine technically. But Phase 6 is about getting Docker working correctly first. `USER` is a production hardening step we add when the setup is stable and we are close to actual deployment.

---

## Commands That Look Similar — Side by Side

### COPY vs ADD

| | `COPY` | `ADD` |
|---|---|---|
| Copy local files | Yes | Yes |
| Extract tar archives | No | Yes |
| Fetch from URL | No | Yes |
| Recommended default | Yes | No |

**Rule:** Use `COPY` unless you specifically need tar extraction.

---

### RUN vs CMD vs ENTRYPOINT

| | When it runs | Purpose |
|---|---|---|
| `RUN` | **Build time** — when building the image | Set up the environment (install packages, create files) |
| `CMD` | **Run time** — when container starts | Default command to execute |
| `ENTRYPOINT` | **Run time** — when container starts | Fixed command, always runs |

```
docker build   →  FROM, RUN, COPY, ADD execute here
docker run     →  ENTRYPOINT + CMD execute here
```

---

### ENV vs ARG

| | `ENV` | `ARG` |
|---|---|---|
| Available during build | Yes | Yes |
| Available at runtime | Yes | No |
| Use case | Runtime config, Python flags | Build-time parameterization |
| Safe for secrets | No | No |

---

### Shell form vs Exec form

```dockerfile
RUN pip install flask          # shell form
RUN ["pip", "install", "flask"] # exec form (rare for RUN)

CMD uvicorn app.main:app        # shell form — PID 1 is /bin/sh
CMD ["uvicorn", "app.main:app"] # exec form — PID 1 is uvicorn
```

**For `CMD` and `ENTRYPOINT`: always use exec form.** Your process becomes PID 1 and receives signals correctly.

---

## Edge Cases and Gotchas

### 1. Build context size
Docker sends your entire build directory to the Docker daemon before building. A `node_modules/` folder or `.venv/` can be hundreds of MB. Without `.dockerignore`, every build is slow even if nothing relevant changed. Always create `.dockerignore` first.

### 2. Layer cache invalidation chain
Once a layer is invalidated (its instruction or inputs changed), **all layers after it are also invalidated**. The cache doesn't skip around. So if you change `requirements.txt`, every instruction after that `RUN pip install` rebuilds.

### 3. `RUN` commands don't persist between instructions
```dockerfile
RUN export MY_VAR=hello   # set in this shell
RUN echo $MY_VAR          # EMPTY — different shell process
```
Each `RUN` is a new shell. Use `ENV` for variables that need to persist.

### 4. `WORKDIR` creates the directory
```dockerfile
WORKDIR /app/subdir   # creates /app and /app/subdir if they don't exist
```

### 5. COPY respects .dockerignore
Files excluded in `.dockerignore` are not available to `COPY`. If you `.dockerignore` a file you then try to `COPY`, the build fails.

### 6. CMD is not a shell — it won't expand variables by default
```dockerfile
CMD ["uvicorn", "app.main:app", "--port", "$PORT"]  # $PORT is literal string
CMD uvicorn app.main:app --port $PORT               # $PORT expands (shell form)
```
If you need environment variable expansion in CMD, use shell form — but then accept the PID 1 tradeoff, or use a wrapper script.

---

## What Our Dockerfile Will Look Like

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Line by line:
1. Start from Python 3.11 slim base
2. All work happens in `/app`
3. Copy requirements first (cache optimization)
4. Install deps (this layer is cached unless requirements.txt changes)
5. Copy all code (invalidated on every code change — intentional, it's fast)
6. Set Python to not buffer output (so logs appear immediately)
7. Document the port (informational)
8. Start uvicorn listening on all interfaces (`0.0.0.0` means accept connections from outside the container, not just localhost)
