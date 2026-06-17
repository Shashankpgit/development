# Docker — Part 02: Dockerfile and Building Images

The Dockerfile is where Docker's real power lives. Writing good Dockerfiles means smaller images, faster builds, and more secure containers.

---

## Dockerfile Instructions Reference

### `FROM` — Base Image

Every Dockerfile must start with `FROM`. It sets the base image — the starting layer you build on top of.

```dockerfile
FROM ubuntu:22.04
FROM node:18-alpine          # alpine = minimal Linux (5MB vs 200MB)
FROM python:3.11-slim        # slim = smaller than default, larger than alpine
FROM scratch                 # empty — for ultra-minimal images (Go binaries)
```

**Choosing the right base:**
- `ubuntu`, `debian` — familiar, large (~200MB)
- `alpine` — tiny (5MB), uses musl libc (some packages behave differently)
- `slim` — reduced debian (~50-80MB), good balance
- `distroless` (Google) — only runtime, no shell, most secure

### `WORKDIR` — Set Working Directory

```dockerfile
WORKDIR /app
```

Sets the working directory for all subsequent instructions. Creates the directory if it doesn't exist. Like `mkdir -p /app && cd /app` but for the image build.

### `COPY` vs `ADD`

```dockerfile
COPY src/ /app/src/           # copy files from host into image
COPY package*.json ./         # copy package.json and package-lock.json

ADD archive.tar.gz /app/      # ADD can extract tar archives and fetch URLs
```

**Always use `COPY` unless you specifically need `ADD`'s tar extraction.** `ADD` has less predictable behavior.

### `RUN` — Execute Commands During Build

```dockerfile
RUN apt-get update && apt-get install -y curl
RUN npm install --production
RUN pip install -r requirements.txt
```

Each `RUN` creates a new layer. **Combine related commands with `&&` to keep the layer count low:**

```dockerfile
# BAD — 3 layers, each takes space
RUN apt-get update
RUN apt-get install -y curl wget
RUN rm -rf /var/lib/apt/lists/*

# GOOD — 1 layer
RUN apt-get update \
    && apt-get install -y curl wget \
    && rm -rf /var/lib/apt/lists/*
```

### `ENV` — Environment Variables

```dockerfile
ENV NODE_ENV=production
ENV PORT=3000
ENV APP_VERSION=1.0.0
```

Available at build time AND runtime (inside running containers). Can be overridden at runtime: `docker run -e NODE_ENV=development ...`

### `ARG` — Build-Time Variables

```dockerfile
ARG APP_VERSION=latest
ARG BUILD_DATE
```

Only available during the build process (`docker build`), NOT in running containers. Pass from command line: `docker build --build-arg APP_VERSION=2.0 .`

### `EXPOSE` — Document Ports

```dockerfile
EXPOSE 3000
EXPOSE 5432
```

This is **documentation only** — it does NOT actually publish the port. You still need `-p` in `docker run`. But it tells users and tools what port the container expects to use.

### `CMD` vs `ENTRYPOINT`

Both define what runs when the container starts — but differently:

```dockerfile
# CMD — default command, COMPLETELY REPLACED if you pass a command to docker run
CMD ["node", "src/index.js"]
# docker run myapp                  → runs: node src/index.js
# docker run myapp bash             → runs: bash  (CMD ignored entirely)

# ENTRYPOINT — fixed executable, arguments can be appended
ENTRYPOINT ["node"]
CMD ["src/index.js"]
# docker run myapp                  → runs: node src/index.js
# docker run myapp src/other.js     → runs: node src/other.js (CMD replaced, ENTRYPOINT kept)
```

**Best practice for applications:** Use `ENTRYPOINT` + `CMD` together. ENTRYPOINT sets the fixed executable, CMD provides defaults that can be overridden.

### `VOLUME` — Declare Mount Points

```dockerfile
VOLUME /app/data
VOLUME /var/log
```

Marks these paths as volumes — data here persists even if the container is deleted. Can be overridden with `-v` in `docker run`.

### `USER` — Run as Non-Root

```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

By default containers run as root — a security risk. Always set a non-root user for production images.

### `HEALTHCHECK` — Container Health Monitoring

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

Docker (and Kubernetes) will run this command periodically. If it fails 3 times, the container is marked "unhealthy."

---

## A Complete Production-Quality Dockerfile

```dockerfile
# ─── Build Stage ───────────────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app

# Copy dependency files FIRST (layer cache optimization)
COPY package*.json ./
RUN npm ci --only=production

# ─── Production Stage ──────────────────────────────────────────
FROM node:18-alpine AS production

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only what's needed from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=appuser:appgroup src/ ./src/
COPY --chown=appuser:appgroup package.json ./

# Switch to non-root user
USER appuser

# Runtime environment
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

ENTRYPOINT ["node"]
CMD ["src/index.js"]
```

---

## Multi-Stage Builds — The Most Important Optimization

Multi-stage builds let you use one stage for building (with compilers, build tools) and a smaller stage for the final image (only the runtime needed).

**Real example — Go application:**

```dockerfile
# Stage 1: Build the Go binary
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o server .

# Stage 2: Minimal production image
FROM alpine:3.18
WORKDIR /app
COPY --from=builder /app/server .
EXPOSE 8080
CMD ["./server"]
```

| Stage | Size |
|-------|------|
| golang:1.21 (build stage) | ~800MB (not in final image) |
| alpine:3.18 + binary | ~12MB |

The final image is 12MB instead of 800MB because the Go compiler, source code, and build tools are left behind in the builder stage.

---

## Building Images

```bash
# Build an image from Dockerfile in current directory
docker build -t myapp:v1.0 .

# Build from specific Dockerfile
docker build -f Dockerfile.prod -t myapp:prod .

# Build with build arguments
docker build --build-arg APP_VERSION=2.0 -t myapp:v2.0 .

# Build for multiple platforms (ARM + x86)
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:v1.0 .

# Build without using cache (fresh build)
docker build --no-cache -t myapp:v1.0 .
```

### Tag management:

```bash
# Add additional tags to an existing image
docker tag myapp:v1.0 myapp:latest
docker tag myapp:v1.0 registry.example.com/myapp:v1.0

# Push to registry
docker push myapp:v1.0
docker push registry.example.com/myapp:v1.0
```

---

## `.dockerignore` — Speed Up Builds and Reduce Image Size

Like `.gitignore`, but tells Docker what to EXCLUDE from the build context (what gets sent to the daemon):

```
node_modules/
.git/
.env
*.log
dist/
coverage/
.DS_Store
README.md
tests/
docs/
```

Without `.dockerignore`, `docker build .` sends your entire project (including `node_modules/` which can be 500MB) to the Docker daemon before starting the build. This makes every build slow and inflates the image.

---

## Layer Caching — The Key to Fast Builds

Docker caches each layer. If a layer hasn't changed since the last build, Docker reuses the cache instead of re-running that step.

**The cache invalidation rule:** If a layer changes, ALL subsequent layers are rebuilt.

**Optimize by putting things that change rarely at the top:**

```dockerfile
# SLOW BUILD — code changes = reinstall all dependencies
COPY . .                         # your code (changes frequently)
RUN npm install                  # dependencies (slow, rebuilds every time)

# FAST BUILD — code changes = only re-copy code, npm install is cached
COPY package*.json ./            # dependency files (rarely change)
RUN npm install                  # only runs when package.json changes
COPY . .                         # your code (cached npm install above is preserved)
```

---

## Common Misunderstanding: "Each RUN creates a separate layer that can be cleaned up later"

**The misunderstanding:** "I can install packages in one RUN and then clean them up in a separate RUN layer."

**The reality:** Even if you delete files in a subsequent layer, the files still exist in the previous layer and contribute to the image size. Docker images include all layers.

```dockerfile
# WRONG — the apt cache is still in layer 2 even though layer 3 deletes it
RUN apt-get update
RUN apt-get install -y build-essential
RUN rm -rf /var/lib/apt/lists/*     # too late! Layer 2 already has the cache

# CORRECT — clean up in the SAME layer
RUN apt-get update \
    && apt-get install -y build-essential \
    && rm -rf /var/lib/apt/lists/*   # removed before this layer is committed
```

→ Continue to: `03-volumes-and-networking.md`
