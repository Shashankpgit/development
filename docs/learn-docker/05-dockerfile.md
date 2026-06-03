# 05 — Dockerfile

A Dockerfile is a plain text script that tells Docker how to build an image. Every line is an instruction. Docker executes them top to bottom, and each instruction that modifies the filesystem creates a **layer**.

Think of it like a recipe: ingredients (base image), preparation steps (RUN commands), and the final dish (your image).

---

## The Layer System — The Most Important Concept

Before learning any commands, you need to understand layers. Every other Dockerfile decision flows from this.

Every `RUN`, `COPY`, and `ADD` instruction creates a new layer. A layer is a **diff** — it records only what changed compared to the previous layer. Layers are:

- **Cached** — if the instruction and its inputs haven't changed, Docker reuses the cached version. This is what makes rebuilds fast.
- **Immutable** — once created, a layer never changes
- **Stacked** — the final image is all layers stacked, each on top of the previous

```
Layer 4: COPY . .              ← diff: added your app code
Layer 3: RUN pip install ...   ← diff: added Python packages
Layer 2: COPY requirements.txt ← diff: added requirements.txt
Layer 1: FROM python:3.11-slim ← diff: the full base image
         ───────────────────
         Final image = all 4 layers combined
```

### Why layer order matters enormously

```dockerfile
# BAD — code changes bust the pip cache every time
COPY . .
RUN pip install -r requirements.txt

# GOOD — pip cache survives code changes
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

When you change any file in your project and rebuild:
- **Bad order:** Docker sees `COPY . .` changed → invalidates that layer → reruns `pip install` (slow, every time)
- **Good order:** Docker sees `requirements.txt` unchanged → reuses cached pip layer → only reruns `COPY . .` (fast, just a file copy)

**Golden rule: put things that change rarely near the top, things that change often near the bottom.**

Once a layer's cache is invalidated, **all layers below it are also invalidated**. The cache doesn't skip around.

---

## Every Dockerfile Instruction

### FROM

```dockerfile
FROM python:3.11-slim
```

Every Dockerfile must start with `FROM`. It sets the base image — the foundation your image is built on top of. You are not building from scratch; you are inheriting from an existing image.

`python:3.11-slim` means: the official Python 3.11 image, slim variant (stripped of unnecessary tools to keep size small).

**Image variants you'll see:**

| Tag | What it means | Size |
|---|---|---|
| `python:3.11` | Full image, includes compilers and tools | ~900MB |
| `python:3.11-slim` | Stripped down, no compilers | ~130MB |
| `python:3.11-alpine` | Tiny, uses musl libc instead of glibc | ~50MB |
| `python:3.11-slim-bookworm` | Slim + Debian Bookworm base | ~130MB |

**Alpine gotcha:** Alpine uses musl libc. Some Python packages (especially those with C extensions like `psycopg2`, `numpy`) don't have Alpine-compatible wheels and have to be compiled from source — which requires build tools and can cause obscure errors. Stick with `slim` unless you have a specific reason.

**Scratch:** `FROM scratch` is an empty image — nothing at all. Used for statically compiled binaries (Go, Rust) that need no OS libraries.

---

### WORKDIR

```dockerfile
WORKDIR /app
```

Sets the working directory for all subsequent instructions. If the directory doesn't exist, Docker creates it. Every `RUN`, `COPY`, `CMD` after this runs relative to `/app`.

Without `WORKDIR`, your files would land in the root `/` — messy and error-prone.

**You can have multiple WORKDIR instructions:**
```dockerfile
WORKDIR /app
COPY . .
WORKDIR /app/scripts   # switch to a subdirectory
RUN ./setup.sh
```

**WORKDIR creates directories automatically:**
```dockerfile
WORKDIR /app/nested/path   # creates /app, /app/nested, /app/nested/path
```

---

### COPY

```dockerfile
COPY requirements.txt .
COPY . .
COPY src/ /app/src/
```

Copies files from the **build context** (your host machine) into the image.

- First argument: source path (relative to build context root)
- Second argument: destination path in image (`.` means current `WORKDIR`)

**What is the build context?** When you run `docker build .`, Docker sends the entire directory (`.`) to the Docker daemon. Only files inside that directory can be copied. This is why you can't `COPY ../secrets.env` — it's outside the context. See [06-build-context-and-ignore.md](06-build-context-and-ignore.md) for the full picture.

```dockerfile
COPY --chown=user:group . .    # copy and set ownership in one step (better than chmod after)
COPY --chmod=755 script.sh /app/
```

---

### ADD

```dockerfile
ADD archive.tar.gz /app/
ADD https://example.com/file.txt /app/   # DON'T DO THIS
```

`ADD` does everything `COPY` does, plus two extras:
1. If the source is a `.tar.gz`, `.zip`, etc. — it automatically extracts it
2. Source can be a URL — Docker fetches it

**When to use `ADD` vs `COPY`:**

| Feature | `COPY` | `ADD` |
|---|---|---|
| Copy local files | ✅ | ✅ |
| Extract tar archives | ❌ | ✅ |
| Fetch from URL | ❌ | ✅ (don't use this) |
| Recommended default | ✅ | ❌ |

**Rule: default to `COPY`. Use `ADD` only when you need tar extraction.**

URL fetching via `ADD` is bad practice — it's not cached properly and is invisible as a network call. If you need to fetch a file, use `RUN curl` instead.

---

### RUN

```dockerfile
RUN pip install --no-cache-dir -r requirements.txt
RUN apt-get update && apt-get install -y curl && apt-get clean
```

Executes a command **at build time** and commits the result as a new layer. Used for installing packages, creating directories, setting permissions.

**Layer count — combine commands:**

Each `RUN` creates a layer. More layers = larger image because layer metadata has overhead.

```dockerfile
# BAD — 3 layers, bigger image
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get clean

# GOOD — 1 layer, smaller image
RUN apt-get update && apt-get install -y curl && apt-get clean
```

Split across lines for readability with `\`:

```dockerfile
RUN apt-get update \
    && apt-get install -y \
        curl \
        git \
        libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

**`--no-cache-dir` in pip:** Tells pip not to save downloaded packages to pip's cache on disk. Inside a Docker image, that cache would just waste space — you'll never reuse it.

**RUN commands don't share state:**
```dockerfile
RUN export MY_VAR=hello   # set in this shell process
RUN echo $MY_VAR          # EMPTY — different shell process, different RUN
```

Each `RUN` is a new shell. Use `ENV` for persistent variables.

---

### ENV

```dockerfile
ENV APP_ENV=production
ENV PYTHONUNBUFFERED=1
ENV PORT=8000
```

Sets environment variables available **both during build and when the container runs**.

**`PYTHONUNBUFFERED=1`** is a common Python setting — forces Python to flush stdout/stderr immediately rather than buffering. Without it, your `print()` and log statements may not appear in `docker logs` in real time (they're buffered in a pipe and only flushed when the buffer fills or the program exits).

Multiple variables in one instruction:
```dockerfile
ENV APP_ENV=production \
    PYTHONUNBUFFERED=1 \
    PORT=8000
```

---

### ARG

```dockerfile
ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim

ARG BUILD_DATE
LABEL build-date=$BUILD_DATE
```

Build-time variable. Only available during `docker build`, **not** when the container runs.

```bash
docker build --build-arg PYTHON_VERSION=3.12 .
docker build --build-arg BUILD_DATE=$(date -u +%Y-%m-%d) .
```

**ENV vs ARG — the most confused pair:**

| | `ENV` | `ARG` |
|---|---|---|
| Available during build | ✅ | ✅ |
| Available at runtime | ✅ | ❌ |
| Visible in `docker inspect` | ✅ | ❌ |
| Can be overridden at runtime with `-e` | ✅ | ❌ |
| Safe for secrets | ❌ | ❌ (visible in build history) |

`ARG` before `FROM`: ARGs declared before FROM are available in `FROM` and then go out of scope. To use them again, re-declare with `ARG` (no value) after FROM:

```dockerfile
ARG BASE_VERSION=3.11
FROM python:${BASE_VERSION}-slim
ARG BASE_VERSION   # re-declare to use it again below FROM
RUN echo "Building with Python $BASE_VERSION"
```

---

### EXPOSE

```dockerfile
EXPOSE 8000
EXPOSE 8000/tcp
EXPOSE 8000/udp
```

Documents that the container listens on port 8000. It does **not** actually open or publish the port.

**The most common beginner confusion:** `EXPOSE` does nothing at runtime. The port is not accessible from outside the container just because you added `EXPOSE`. The actual port publishing happens with:
- `docker run -p 8080:8000` — maps host port 8080 to container port 8000
- `ports: - "8080:8000"` in docker-compose.yml

`EXPOSE` is purely documentation. It tells the person running the container "this is the port the app listens on". Tools like docker-compose can read it for automatic port assignment in some modes.

---

### CMD

```dockerfile
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Defines the **default command** to run when a container starts. There can only be one `CMD` — if you write multiple, only the last one takes effect.

**CMD can be overridden** at runtime:
```bash
docker run myimage python3 debug_script.py    # overrides CMD
```

### Shell form vs Exec form

This is one of the most important distinctions in Dockerfiles:

```dockerfile
# Shell form — runs via /bin/sh -c
CMD uvicorn app.main:app --host 0.0.0.0

# Exec form — runs directly, no shell involved
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0"]
```

**Always use exec form (the array) for CMD and ENTRYPOINT.**

Why? With shell form:
- Docker runs `/bin/sh -c "uvicorn app.main:app ..."` 
- `/bin/sh` becomes PID 1
- Your app is a child process of the shell
- When Docker stops the container (sends SIGTERM), the shell gets it — and may not forward it to your app
- Your app does not get a chance for graceful shutdown

With exec form:
- Docker runs `uvicorn` directly
- `uvicorn` becomes PID 1
- Docker sends SIGTERM directly to your app
- Graceful shutdown works correctly

**Exception:** If you need environment variable expansion in CMD, shell form is easier:
```dockerfile
CMD uvicorn app.main:app --port $PORT    # $PORT expands (shell form)
CMD ["uvicorn", "app.main:app", "--port", "$PORT"]  # $PORT is literal string (exec form)
```

For exec form with variable expansion, use a wrapper script or `sh -c` explicitly:
```dockerfile
CMD ["/bin/sh", "-c", "uvicorn app.main:app --port $PORT"]
```

---

### ENTRYPOINT

```dockerfile
ENTRYPOINT ["uvicorn"]
CMD ["app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

`ENTRYPOINT` sets the fixed command that always runs. `CMD` provides default arguments to it.

Combined: `uvicorn app.main:app --host 0.0.0.0 --port 8000`

| | `CMD` alone | `ENTRYPOINT` + `CMD` |
|---|---|---|
| Overridable at runtime | Yes — `docker run img other-command` | Hard — requires `--entrypoint` flag |
| Arguments overridable | Yes | Yes — just override CMD |
| Typical use case | Default command for general-purpose images | Fixed tool images (the command never changes) |

**Example:** A container that is always a linter:
```dockerfile
ENTRYPOINT ["pylint"]
CMD ["--help"]   # default: show help
# docker run linter myfile.py  → runs "pylint myfile.py"
```

**For most web apps:** Use `CMD` alone. `ENTRYPOINT` makes more sense for CLI tool images.

---

### HEALTHCHECK

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1
```

Tells Docker how to test if the container is healthy. Docker runs this command periodically.

| Option | Default | Meaning |
|---|---|---|
| `--interval` | 30s | How often to run the check |
| `--timeout` | 30s | How long to wait for the check to complete |
| `--start-period` | 0s | Grace period before checks start (for slow-starting apps) |
| `--retries` | 3 | How many failures before marking unhealthy |

The check command exits 0 = healthy, non-zero = unhealthy.

```bash
docker ps    # shows "healthy" or "unhealthy" in the STATUS column
```

Critical for docker-compose's `depends_on: condition: service_healthy` — without HEALTHCHECK, docker-compose can't know when a service is truly ready. (See [10-docker-compose.md](10-docker-compose.md))

---

### USER

```dockerfile
RUN adduser --disabled-password --no-create-home appuser
USER appuser
```

By default, everything inside a container runs as **root** (uid 0). This is a security risk.

**Why running as root is dangerous:**

If a bug in your app allows an attacker to run arbitrary commands (a real class of vulnerability — e.g., command injection, deserialization flaws), they execute those commands as root. If they find a way to escape the container namespace (rare but has happened), they land on the host as root. Full access.

**What USER does:**

Creates a normal system user and switches all subsequent instructions — and the final CMD — to run as that user. The attacker's potential foothold becomes a low-privilege nobody.

```dockerfile
# Create a system user (no password, no home directory needed)
RUN adduser --disabled-password --no-create-home appuser \
    && chown -R appuser:appuser /app   # ensure the app directory is owned by appuser

# Switch to non-root user — CMD will run as appuser
USER appuser
```

**The file permission gotcha:**

After `COPY . .`, files are owned by root. If `appuser` needs to write to any directory (logs, uploads, temp files), you must `chown` it before switching:

```dockerfile
RUN adduser --disabled-password --no-create-home appuser \
    && chown -R appuser:appuser /app

USER appuser
```

---

### VOLUME

```dockerfile
VOLUME /data
VOLUME ["/var/lib/postgresql/data"]
```

Declares a mount point and marks it as holding externally-mounted data. When a container starts without a volume mounted at this path, Docker automatically creates an anonymous volume.

**Gotcha:** `VOLUME` in a Dockerfile creates an anonymous volume automatically — but Docker assigns it a random UUID name. You lose control over naming. This makes it hard to find and reuse later.

**Better practice:** Don't use `VOLUME` in Dockerfiles. Instead, explicitly mount volumes when running the container or in docker-compose. This gives you named, manageable volumes.

---

### LABEL

```dockerfile
LABEL maintainer="you@example.com"
LABEL version="1.0.0"
LABEL description="My web application"
LABEL org.opencontainers.image.source="https://github.com/user/repo"
```

Adds metadata to the image as key-value pairs. Visible via `docker inspect`.

Use the [OCI image annotation spec](https://github.com/opencontainers/image-spec/blob/main/annotations.md) for standard keys.

---

### ONBUILD

```dockerfile
ONBUILD COPY . /app/src
ONBUILD RUN pip install -r requirements.txt
```

Deferred instructions — they run when this image is used as a **base image** in another Dockerfile's FROM. Designed for creating base images for teams.

Rarely used in application Dockerfiles. Mentioned here for completeness.

---

### SHELL

```dockerfile
SHELL ["/bin/bash", "-c"]
```

Changes the default shell used for shell-form RUN/CMD/ENTRYPOINT instructions. Default is `["/bin/sh", "-c"]`. Use this if you need bash-specific syntax:

```dockerfile
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN pip install flask | tee /tmp/pip.log && echo "done"
```

`-o pipefail` makes the pipeline fail if any command in it fails (not just the last one).

---

## Complete Comparison Tables

### RUN vs CMD vs ENTRYPOINT

| | When it runs | Purpose | Can it modify the filesystem? |
|---|---|---|---|
| `RUN` | Build time | Set up the image (install packages, create files) | Yes — creates a layer |
| `CMD` | Run time | Default command when container starts | No |
| `ENTRYPOINT` | Run time | Fixed command that always runs | No |

```
docker build   →  FROM, RUN, COPY, ADD, ENV, ARG, LABEL, WORKDIR run here
docker run     →  CMD and ENTRYPOINT run here
```

### COPY vs ADD

| Feature | `COPY` | `ADD` |
|---|---|---|
| Copy local files | ✅ | ✅ |
| Extract tar archives | ❌ | ✅ |
| Fetch from URL | ❌ | ✅ (don't) |
| Recommended default | ✅ | Use only for tar |

### Shell form vs Exec form

| | Shell form | Exec form |
|---|---|---|
| Syntax | `CMD command args` | `CMD ["command", "args"]` |
| Runs via | `/bin/sh -c` | Directly |
| PID 1 | The shell | Your command |
| Signal handling | Poor (shell may not forward) | Correct (receives SIGTERM directly) |
| Variable expansion | Yes (`$VAR` works) | No (`$VAR` is literal) |
| Use for CMD/ENTRYPOINT | Avoid | Yes |
| Use for RUN | Common | Rare |

---

## Common Gotchas

### 1. Build context size
Docker sends your entire build directory to the daemon before building. Without `.dockerignore`, a project with `node_modules/` or `.venv/` can be hundreds of MB. Every build is slow regardless of what changed. Always create `.dockerignore` first. (See [06-build-context-and-ignore.md](06-build-context-and-ignore.md))

### 2. Cache invalidation chain
Once a layer is invalidated, **all subsequent layers are also invalidated**. The cache does not skip around. Change a line in your code → COPY . . cache miss → every instruction after it rebuilds.

### 3. ENV variable scope
ENV variables set in one `RUN` are available in later instructions because ENV persists. But variables set via `export` in a RUN are not:
```dockerfile
ENV DB_HOST=localhost           # persists — available to all subsequent instructions
RUN export TEMP=value           # does NOT persist — shell-local to this RUN only
RUN echo $TEMP                  # prints nothing
```

### 4. CMD is overridden by `docker run` arguments
```bash
docker run myimage              # runs CMD
docker run myimage bash         # overrides CMD, runs bash instead
```

### 5. EXPOSE does nothing at runtime
Adding `EXPOSE 8000` does not open port 8000. Use `-p` flag with `docker run` or `ports:` in docker-compose.

### 6. Running as root by default
Unless you explicitly add a `USER` instruction, your container runs as root. This is a security concern for production.

### 7. .env is not auto-loaded in containers
Docker does not read `.env` files automatically inside containers. You must pass variables explicitly via `-e`, `--env-file`, or compose's `env_file`. More in [11-environment-variables.md](11-environment-variables.md).

---

## A Production-Ready Dockerfile

Putting it all together — a hardened Dockerfile for a Python web app:

```dockerfile
# Use a specific version, never "latest" in production
FROM python:3.11-slim

# Metadata
LABEL maintainer="you@example.com" \
      version="1.0.0"

# Keeps Python from buffering stdout/stderr
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# All subsequent instructions run in /app
WORKDIR /app

# Copy only requirements first — cache pip install as long as requirements don't change
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code (busts cache on every code change — expected)
COPY . .

# Create non-root user and take ownership
RUN adduser --disabled-password --no-create-home appuser \
    && chown -R appuser:appuser /app

# Switch to non-root
USER appuser

# Documentation: app listens on 8000
EXPOSE 8000

# Healthcheck so orchestrators know when app is ready
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Exec form — uvicorn becomes PID 1, handles SIGTERM correctly
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Summary

- Every `RUN`, `COPY`, `ADD` creates a layer. Layers are cached and immutable.
- Order matters: rarely-changing things (deps) before frequently-changing things (code).
- Use `COPY` not `ADD`, exec form not shell form, `ENV` not `ARG` for runtime config.
- `EXPOSE` is documentation only — it doesn't open ports.
- `RUN` is build-time, `CMD`/`ENTRYPOINT` are run-time.
- Always add a `USER` instruction for production images.
- `HEALTHCHECK` enables proper dependency ordering in docker-compose.

**Next:** [06 — Build Context & .dockerignore](06-build-context-and-ignore.md)

---

## Reference Links

- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/) — every instruction documented
- [Best practices for writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [PID 1 and signal handling](https://cloud.google.com/architecture/best-practices-for-building-containers#signal-handling)
