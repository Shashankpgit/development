# 07 — Layer Cache Optimization

A Dockerfile that takes 3 minutes to build on the first run should take 5 seconds on subsequent runs. If it doesn't, the layer cache is not being used effectively. This file explains exactly how Docker's caching works and how to structure Dockerfiles to maximize cache hits.

---

## How Docker Decides to Use Cache

For each instruction, Docker computes a **cache key** and checks whether a cached layer with that key already exists.

The cache key is computed from:
1. The instruction itself (the text)
2. The parent layer's cache key
3. For `COPY`/`ADD`: the checksum of every file being copied

If all three match → cache hit, reuse the layer.
If any one differs → cache miss, rebuild this layer (and all subsequent ones).

```
Instruction 1: FROM python:3.11-slim    → cache key A
Instruction 2: COPY requirements.txt . → cache key B (depends on A + file checksum)
Instruction 3: RUN pip install ...      → cache key C (depends on B + instruction text)
Instruction 4: COPY . .                 → cache key D (depends on C + all file checksums)
Instruction 5: CMD [...]                → cache key E (depends on D + instruction text)
```

---

## The Cache Invalidation Chain

**Once one layer misses the cache, all layers below it also miss.** The cache does not skip around.

```
Layer 1: FROM python:3.11-slim       ✅ cache hit
Layer 2: COPY requirements.txt .     ✅ cache hit (file unchanged)
Layer 3: RUN pip install ...         ✅ cache hit
Layer 4: COPY . .                    ❌ cache miss (code changed)
Layer 5: CMD [...]                   ❌ forced rebuild (layer 4 missed)
```

Layer 4 missed because your code changed. Layer 5 is forced to rebuild even though `CMD` didn't change — because Docker cannot reuse a layer without knowing the exact parent state.

**This is the single most important optimization insight:**

> Put instructions whose inputs change rarely near the top. Put instructions whose inputs change on every edit near the bottom.

---

## The Golden Rule: Dependencies Before Code

Dependencies (pip packages, npm packages, Go modules) change rarely. Your code changes constantly.

```dockerfile
# ❌ BAD — code change busts the dependency install cache every time
COPY . .
RUN pip install -r requirements.txt    # reruns on every code change

# ✅ GOOD — dependency install cache is independent of code changes
COPY requirements.txt .
RUN pip install -r requirements.txt    # reruns only when requirements.txt changes
COPY . .                               # this misses cache on code change — expected
```

With the good order, a typical development cycle:
- You edit a Python file → Layer 4 (COPY . .) misses → rebuild in ~2 seconds
- You add a new pip package → Layer 2 misses → pip install runs → ~30 seconds
- You change the base image → Layer 1 misses → full rebuild → ~2 minutes

Fast path (code change) is the most common. The slow path (dependency change) is rare.

---

## Language-Specific Patterns

### Python

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Copy only the requirements file first
COPY requirements.txt .

# Install dependencies — this layer is cached unless requirements.txt changes
RUN pip install --no-cache-dir -r requirements.txt

# Now copy code — this layer is the one that misses cache on code changes
COPY . .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**If you use pyproject.toml / poetry:**
```dockerfile
COPY pyproject.toml poetry.lock ./
RUN pip install poetry && poetry install --no-dev
COPY . .
```

### Node.js

```dockerfile
FROM node:20-slim

WORKDIR /app

# package.json AND package-lock.json (or yarn.lock)
# Both must be copied — the lockfile pins exact versions
COPY package.json package-lock.json ./

# Install node modules — cached unless package files change
RUN npm ci    # npm ci is faster and more reliable than npm install for CI/production

# Copy source code
COPY . .

# Build step (if needed)
RUN npm run build

CMD ["node", "dist/index.js"]
```

**Why `npm ci` over `npm install`:**
- `npm ci` uses exactly what's in `package-lock.json` — reproducible
- `npm ci` deletes `node_modules` before installing — clean slate
- `npm ci` fails if `package.json` and `package-lock.json` are out of sync — catches mistakes

### Go

```dockerfile
FROM golang:1.22-alpine AS builder

WORKDIR /app

# go.mod and go.sum define dependencies — copy first
COPY go.mod go.sum ./

# Download dependencies — cached unless go.mod/go.sum change
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -o server ./cmd/server

FROM alpine:3.19
COPY --from=builder /app/server /server
CMD ["/server"]
```

### Java / Maven

```dockerfile
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /app

# Copy POM file first — defines dependencies
COPY pom.xml .

# Download all dependencies — cached unless pom.xml changes
# The -B flag is batch mode (no interactive), go-offline downloads everything
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build (dependencies already downloaded and cached)
RUN mvn package -DskipTests

FROM eclipse-temurin:21-jre-alpine
COPY --from=builder /app/target/*.jar /app.jar
CMD ["java", "-jar", "/app.jar"]
```

---

## What Invalidates the Cache?

| Instruction | What triggers a cache miss |
|---|---|
| `FROM` | Different image tag, or base image was updated remotely (if you `docker pull` it) |
| `RUN` | The instruction text changes |
| `COPY` | Any file being copied has changed (by content checksum, not timestamp) |
| `ADD` | Same as COPY |
| `ENV` | The instruction text changes |
| `ARG` | The build argument value changes (if used after ARG declaration) |
| `WORKDIR` | The path changes |

**Important:** Docker compares file **contents** (sha256 checksum), not timestamps. Touching a file without changing it does NOT invalidate the cache. This is good — `git pull` on an unchanged file doesn't bust your cache.

---

## Forcing a Cache Bust

Sometimes you want to rebuild even though nothing in the Dockerfile changed. Common scenario: you ran `apt-get update` a week ago and want to get the latest security patches.

```bash
# Skip cache entirely — full rebuild
docker build --no-cache -t myapp .

# Bust cache from a specific layer — add a build arg that changes
docker build --build-arg CACHEBUST=$(date +%s) -t myapp .
```

The `CACHEBUST` arg technique:
```dockerfile
ARG CACHEBUST=1
# Any instruction after this that depends on CACHEBUST will miss cache
RUN apt-get update && apt-get upgrade -y
```

```bash
docker build --build-arg CACHEBUST=$(date +%s) .   # bust the cache at that layer
```

---

## Measuring Layer Sizes

After building, check what each layer contributes:

```bash
docker image history myapp:1.0
```

```
IMAGE         CREATED        CREATED BY                                 SIZE
a1b2c3d4e5   2 minutes ago  CMD ["uvicorn", ...]                      0B
f6g7h8i9j0   2 minutes ago  COPY . .                                  2.1MB
k1l2m3n4o5   4 minutes ago  RUN pip install ...                       89MB
p6q7r8s9t0   4 minutes ago  COPY requirements.txt .                   1.4kB
...
```

A 89MB pip install layer is expected. A 200MB `COPY . .` layer means your context has junk — check `.dockerignore`.

---

## BuildKit Advanced Caching

Docker's BuildKit (enabled by default since Docker 23) supports a `--mount=type=cache` that provides a persistent cache between builds — unlike regular layer caching, this cache is not invalidated by downstream changes.

```dockerfile
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

This keeps pip's download cache across builds in a Docker-managed cache. Even if `requirements.txt` changes and the pip layer needs to rebuild, pip only downloads the changed packages — not everything from scratch.

```dockerfile
# Node.js with npm cache
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Go with module cache
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
```

This is a BuildKit-specific feature. It significantly speeds up rebuilds when dependencies change.

---

## Common Optimization Mistakes

### Mistake 1: Copying everything too early

```dockerfile
# ❌
COPY . .
RUN pip install -r requirements.txt   # always runs on any code change
```

### Mistake 2: Splitting RUN commands unnecessarily

```dockerfile
# ❌ — 4 layers, each adding overhead
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git
RUN apt-get clean

# ✅ — 1 layer
RUN apt-get update \
    && apt-get install -y curl git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

### Mistake 3: Forgetting `rm -rf /var/lib/apt/lists/*`

After `apt-get install`, the downloaded package list cache in `/var/lib/apt/lists/` is no longer needed and takes significant space. Always clean it in the same RUN:

```dockerfile
RUN apt-get update \
    && apt-get install -y libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

If you run `rm -rf /var/lib/apt/lists/*` in a separate RUN, it creates a new layer that hides the files but doesn't actually reduce image size — the files exist in the previous layer.

### Mistake 4: Using `latest` base image tags

```dockerfile
FROM python:latest   # ❌ — "latest" changes, busts your entire cache unexpectedly
FROM python:3.11-slim  # ✅ — pinned, cache is stable
```

### Mistake 5: Not using lockfiles

```dockerfile
RUN npm install          # ❌ — resolves to different versions each time
RUN npm ci               # ✅ — uses package-lock.json exactly
```

---

## Summary

- Docker computes a cache key per layer from the instruction text + parent key + file checksums.
- Once one layer misses, all subsequent layers also miss.
- Put rarely-changing things (deps) before frequently-changing things (code).
- Copy dependency manifests first, install, then copy code — for Python, Node, Go, Java.
- `--no-cache` forces a full rebuild.
- Use `docker image history` to inspect layer sizes.
- BuildKit's `--mount=type=cache` provides persistent cache across builds.

**Next:** [08 — Volumes & Data Persistence](08-volumes.md)

---

## Reference Links

- [Docker build cache](https://docs.docker.com/build/cache/)
- [BuildKit cache mounts](https://docs.docker.com/build/guide/mounts/)
- [Best practices: optimize build cache](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#leverage-build-cache)
