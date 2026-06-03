# 12 — Multi-Stage Builds

A Go binary is 10MB. The Go compiler toolchain needed to build it is 600MB. If you put both in your production image, you're shipping 610MB — when the running container only needs 10MB.

Multi-stage builds solve this by using multiple `FROM` instructions in a single Dockerfile. Each `FROM` starts a new stage. You build in one stage, copy only the output to a smaller final stage.

---

## The Problem: Build Tools Bloat Images

Different languages have different tools needed to compile or bundle code:

| Language | Build tools needed | Runtime needs |
|---|---|---|
| Go | Go compiler, stdlib | Just the binary |
| Rust | Rust compiler, cargo | Just the binary (or nothing for static) |
| Java | JDK (JRE + compiler), Maven/Gradle | JRE only |
| Node.js | Node + devDependencies | Node + production deps only |
| C/C++ | GCC, make, headers | Just the compiled binary |

Without multi-stage builds, you put everything in one image. With them, you build in a large stage and copy only what you need to a minimal final stage.

---

## The Syntax

```dockerfile
# Stage 1: named "builder"
FROM golang:1.22 AS builder
WORKDIR /app
COPY . .
RUN go build -o server ./cmd/server

# Stage 2: the final, small image
FROM alpine:3.19
COPY --from=builder /app/server /server    # copy only the binary from builder
CMD ["/server"]
```

Key elements:
- `AS builder` — names the stage. The name is used in `--from=`.
- `COPY --from=builder` — copies files from another stage (not the host).
- The second `FROM` starts a fresh image with no knowledge of the first stage.

---

## Pattern 1: Go — Static Binary

Go compiles to a static binary that needs no OS libraries. The final image can be `scratch` (literally empty):

```dockerfile
# ─── Build Stage ────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Download dependencies first (cache layer)
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \          # strip debug info, reduce binary size
    -o server \
    ./cmd/server

# ─── Final Stage ────────────────────────────────────────────────
FROM scratch
# scratch = completely empty image — no shell, no OS utilities, nothing

COPY --from=builder /app/server /server

# If you need TLS certificates (for HTTPS calls)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

EXPOSE 8080
CMD ["/server"]
```

Result:
- Builder stage: ~600MB (full Go toolchain)
- Final image: ~10MB (just the binary)

**Why `-ldflags="-w -s"`:**
- `-w`: strip DWARF debug information
- `-s`: strip symbol table
Combined these can shrink a Go binary by 30-50%.

---

## Pattern 2: Node.js — Build React, Serve with Nginx

A React app needs Node + all devDependencies to build, but the output is just static HTML/CSS/JS that nginx can serve. No Node needed at runtime.

```dockerfile
# ─── Build Stage ────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Dependencies first (cache layer)
COPY package.json package-lock.json ./
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build   # creates /app/dist or /app/build

# ─── Final Stage ────────────────────────────────────────────────
FROM nginx:alpine

# Copy the built static files to nginx's serving directory
COPY --from=builder /app/dist /usr/share/nginx/html

# Custom nginx config (optional)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
# nginx starts automatically — no CMD needed (defined in the nginx image)
```

Result:
- Builder: ~400MB (Node + devDependencies)
- Final image: ~25MB (nginx + your static files)

---

## Pattern 3: Python — Separate Install from Runtime

Python has build tools (`gcc`, header files) needed for some packages with C extensions. You can compile in a full image and copy the installed packages to a slim runtime:

```dockerfile
# ─── Build Stage ────────────────────────────────────────────────
FROM python:3.11 AS builder

WORKDIR /app

# Install build dependencies needed for C extensions
RUN apt-get update && apt-get install -y gcc libpq-dev

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
#               ↑ --prefix installs to /install instead of default location

# ─── Final Stage ────────────────────────────────────────────────
FROM python:3.11-slim

# Copy compiled packages from builder
COPY --from=builder /install /usr/local

WORKDIR /app
COPY . .

ENV PYTHONUNBUFFERED=1
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**When you need this:** When some Python packages (like `psycopg2`, `Pillow`) require C compilation and don't have pre-built wheels for `slim` or `alpine`. Build in the full image, copy results to slim.

**Simpler Python approach:** Use packages that have wheels (`psycopg2-binary` instead of `psycopg2`). Then the compilation step is unnecessary and you can use a single-stage slim Dockerfile.

---

## Pattern 4: Java — JDK to JRE

```dockerfile
# ─── Build Stage ────────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /app

# Dependency download first (cache)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Build
COPY src ./src
RUN mvn package -DskipTests -B

# ─── Final Stage ────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine
# JRE only — no compiler, no Maven

WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
```

Result:
- Builder: ~600MB (JDK + Maven)
- Final image: ~80MB (JRE only)

---

## Pattern 5: Including a Test Stage

Multi-stage builds can also include a test stage that you can optionally target:

```dockerfile
FROM python:3.11-slim AS base
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

# ─── Test Stage ─────────────────────────────────────────────────
FROM base AS test
RUN pip install --no-cache-dir pytest
RUN pytest tests/   # fails the build if tests fail

# ─── Production Stage ───────────────────────────────────────────
FROM base AS production
ENV PYTHONUNBUFFERED=1
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

In CI:
```bash
# Run tests (stops at test stage)
docker build --target test -t myapp:test .

# Build production (skips test stage)
docker build --target production -t myapp:prod .
```

---

## --target: Build Only a Specific Stage

```bash
# Build only up to the "builder" stage
docker build --target builder -t myapp:build-only .

# Inspect the builder stage interactively
docker run --rm -it myapp:build-only sh
```

Useful for debugging — inspect intermediate stages when something goes wrong.

---

## COPY --from: Not Just From Stages

`COPY --from` can also copy from external images (not just stages in the same Dockerfile):

```dockerfile
# Copy a binary from another image without having to install it
COPY --from=alpine/curl:latest /usr/bin/curl /usr/bin/curl
COPY --from=golang:1.22 /usr/local/go /usr/local/go
```

This is a way to compose an image from multiple sources.

---

## Distroless Images — Smaller Than Alpine

Google's "distroless" images contain only your app and its runtime dependencies — no shell, no package manager, no OS utilities. Even smaller attack surface than Alpine.

```dockerfile
FROM golang:1.22 AS builder
# ... build ...

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/server /server
CMD ["/server"]
```

```dockerfile
# Python distroless
FROM gcr.io/distroless/python3-debian12
COPY --from=builder /app /app
CMD ["app.main"]
```

**Trade-off:** No shell inside the container. `docker exec mycontainer bash` doesn't work. Debugging is harder. For production, this is often the right trade-off; for development, stick with slim.

---

## Measuring the Difference

Always verify the size improvement:

```bash
# Build both and compare
docker build --target builder -t myapp:builder .
docker build -t myapp:final .

docker images myapp
# REPOSITORY  TAG      IMAGE ID       SIZE
# myapp       builder  a1b2c3d4e5f6   612MB
# myapp       final    f6e5d4c3b2a1   12.4MB
```

---

## When Not to Use Multi-Stage Builds

- **Interpreted languages with no compilation step** (Python apps that only use pure-Python packages, Ruby, PHP) — the benefit is small. Single-stage with a slim base is sufficient.
- **Small projects where build time matters more than image size** — multi-stage adds a small amount of complexity.
- **Development images** — you want the build tools available for debugging. Use multi-stage only for production images.

---

## Summary

- Multi-stage builds use multiple `FROM` instructions, each starting a new stage
- `COPY --from=stagename` copies artifacts from one stage to another
- Result: ship only what your app needs to run — not the build tools
- Common patterns: Go→scratch, Node→nginx, Java→JRE, Python→slim
- `--target stagename` builds only up to a specific stage (useful for CI and debugging)
- Distroless images are even smaller than Alpine — no shell, minimal attack surface

**Next:** [13 — Registry & Image Management](13-registry-and-images.md)

---

## Reference Links

- [Multi-stage builds documentation](https://docs.docker.com/build/building/multi-stage/)
- [Distroless images by Google](https://github.com/GoogleContainerTools/distroless)
- [Docker official images (slim, alpine, distroless variants)](https://hub.docker.com)
