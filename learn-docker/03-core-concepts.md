# 03 — Core Concepts

Before writing a single Dockerfile or running any complex command, you need a solid mental model of how Docker is structured. This file builds that model from the ground up.

---

## The Big Picture

Here is how every piece fits together:

```
┌────────────────────────────────────────────────────────┐
│                     Your Machine                        │
│                                                         │
│   Dockerfile  ──build──►  Image  ──run──►  Container   │
│                                                         │
│   docker push ──────────────────────────────────────►  │
│                                           Docker Hub   │
│   docker pull ◄──────────────────────────────────────  │
│                                           (Registry)   │
│                                                         │
│   Docker CLI  ──REST API──►  Docker Daemon              │
│   (your terminal)           (background service)       │
└────────────────────────────────────────────────────────┘
```

Let's understand each piece.

---

## Images

### What an image is

An image is a **read-only, immutable package** that contains:
- A filesystem (your app code + all its dependencies + OS libraries)
- Metadata (what environment variables to set, what port to expose, what command to run)
- A set of **layers** stacked on top of each other

Think of it like a class definition in OOP — it defines what something is, but it is not running. You can create many containers from one image, just like you can create many objects from one class.

### Where images come from

1. **You build them** from a Dockerfile using `docker build`
2. **You pull them** from a registry using `docker pull` (or implicitly via `docker run`)
3. **You import them** from a tar file using `docker load`

### Image naming

```
docker.io / library / ubuntu : 22.04
  ↑              ↑        ↑       ↑
registry    namespace   name    tag
```

- **Registry:** `docker.io` is Docker Hub (the default; can be omitted)
- **Namespace:** for official images it's `library` (can be omitted); for user images it's the username
- **Name:** the image name
- **Tag:** a label for a specific version. Defaults to `latest` if omitted — but `latest` is just a convention, not necessarily the newest version

Examples:
```
ubuntu:22.04              → docker.io/library/ubuntu:22.04
nginx:alpine              → docker.io/library/nginx:alpine
postgres:16               → docker.io/library/postgres:16
myusername/myapp:v1.2     → docker.io/myusername/myapp:v1.2
ghcr.io/myorg/myapp:main  → GitHub Container Registry
```

### The layer system

An image is built from layers. Each layer is a diff — it records only what changed compared to the previous layer.

```
Layer 4: COPY . .              ← your app code
Layer 3: RUN pip install ...   ← Python dependencies
Layer 2: COPY requirements.txt ← requirements file
Layer 1: FROM python:3.11-slim ← base OS + Python runtime
```

**Why layers matter:**
- Layers are **cached** — if a layer hasn't changed, Docker reuses it. Builds are fast.
- Layers are **shared** — if two images use the same base layer, it is stored once on disk. Space-efficient.
- Layers are **immutable** — once created, a layer never changes. Images are reproducible.

---

## Containers

### What a container is

A container is a **running instance of an image**.

The image provides the read-only filesystem. When you run a container, Docker adds a thin **writable layer** on top. Everything the running process writes goes into this writable layer.

```
┌─────────────────────────────────────┐
│  Writable layer (container-specific)│  ← writes go here
├─────────────────────────────────────┤
│  Layer 4: COPY . .                  │
│  Layer 3: RUN pip install           │  read-only image layers
│  Layer 2: COPY requirements.txt     │  (shared with all containers
│  Layer 1: FROM python:3.11-slim     │   from this image)
└─────────────────────────────────────┘
```

When you delete the container, the writable layer is deleted. The image layers are untouched. This is why containers are **ephemeral** — they start clean every time.

### Container lifecycle

```
docker create  →  [ created ]
docker start   →  [ running ]
docker stop    →  [ stopped/exited ]
docker start   →  [ running again ]  (same container, same writable layer)
docker rm      →  [ gone forever ]
```

Or more commonly in one command: `docker run` = `create` + `start`.

### Container isolation

Each container gets its own:
- **Filesystem** (via mount namespace) — it sees the image layers + its writable layer
- **Network** (via network namespace) — its own IP, its own loopback (localhost)
- **Process tree** (via PID namespace) — PID 1 inside is different from PID 1 on host
- **Hostname** (via UTS namespace) — defaults to the container ID

This isolation is why **`localhost` inside a container refers to that container** — not your host machine, not another container.

### One process per container (the philosophical rule)

Docker containers are designed around the idea that each container runs one main process. This is not a technical restriction — you can run multiple processes. But the design principle is:

- One container = one service (one database, one web server, one worker)
- Multiple services = multiple containers wired together via Docker Compose

If your container's main process exits, the container stops. That is intentional.

---

## The Docker Daemon

`dockerd` is the background service that does everything:
- Builds images
- Runs containers
- Manages networks and volumes
- Pulls/pushes to registries

It listens on a Unix socket: `/var/run/docker.sock`

The Docker CLI (`docker`) is just a client that sends commands to this socket over a REST API. When you type `docker run nginx`, the CLI sends an HTTP POST request to the daemon and displays the response.

**Why this matters:**
- The daemon runs as root. This is a security consideration — anyone who can talk to `/var/run/docker.sock` has root-equivalent access on the host.
- The daemon must be running for any docker commands to work.
- On Mac/Windows, Docker Desktop manages the daemon inside the VM.

---

## The Docker Registry

A registry is a server that stores and distributes images. When you `docker pull nginx`, you are downloading an image from a registry.

**Docker Hub** (`docker.io` or `hub.docker.com`) is the default registry. It has:
- Official images maintained by vendors: `postgres`, `redis`, `nginx`, `python`, `node`
- Community images uploaded by users: `bitnami/redis`, `grafana/grafana`
- Your own private repositories (free tier: 1 private repo)

**Other registries:**
| Registry | URL | Used For |
|---|---|---|
| Docker Hub | docker.io | Default public registry |
| GitHub Container Registry | ghcr.io | Images tied to GitHub repos |
| AWS ECR | *.amazonaws.com | AWS deployments |
| Google Artifact Registry | *.pkg.dev | GCP deployments |
| Azure Container Registry | *.azurecr.io | Azure deployments |
| Self-hosted | anywhere | Private enterprise use |

---

## BuildKit

Docker's build engine. Since Docker 23, BuildKit is the default. You may see it referenced in docs:

```bash
DOCKER_BUILDKIT=1 docker build .   # force BuildKit (older Docker)
docker buildx build .              # BuildKit-native build
```

BuildKit brings:
- Parallel build stages
- Better cache control (`--mount=type=cache`)
- Build secrets (never bake secrets into layers)
- Multi-platform builds

You do not need to configure this — it is on by default. But knowing the name helps when reading advanced docs.

---

## The Full Flow — From Code to Running Container

```
1. You write your application code

2. You write a Dockerfile describing how to package it

3. docker build -t myapp:1.0 .
   → Docker reads the Dockerfile
   → Executes each instruction, creates layers
   → Produces an image named myapp:1.0

4. docker run -p 8000:8000 myapp:1.0
   → Docker creates a container from the image
   → Adds a writable layer
   → Sets up network namespace, mounts
   → Starts the process defined by CMD
   → Maps port 8000 on host to 8000 in container

5. (Optional) docker push myusername/myapp:1.0
   → Uploads the image to Docker Hub
   → Anyone can now docker pull myusername/myapp:1.0
```

---

## What Lives Where

| Thing | Where it lives |
|---|---|
| Images | `/var/lib/docker/overlay2/` (Linux) or inside the Docker Desktop VM |
| Container data (writable layer) | Same location, deleted when container is removed |
| Named volumes | `/var/lib/docker/volumes/` |
| Docker socket | `/var/run/docker.sock` |
| Docker daemon config | `/etc/docker/daemon.json` |
| Dockerfile | Wherever you put it in your project |

You generally never navigate to these paths manually. Docker commands manage everything. But knowing they exist helps when things go wrong.

---

## Summary

- **Image:** read-only, layered package. The blueprint.
- **Container:** running instance of an image. Adds a writable layer on top.
- **Layer:** a filesystem diff created by each Dockerfile instruction. Cached and shared.
- **Daemon:** the background service that does everything. CLI talks to it via socket.
- **Registry:** image storage server. Docker Hub is the default.
- Container isolation means each container has its own network — `localhost` is per-container.

**Next:** [04 — Essential CLI Commands](04-essential-cli-commands.md)

---

## Reference Links

- [Docker architecture](https://docs.docker.com/get-started/overview/#docker-architecture)
- [Images and containers](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-an-image/)
- [Docker storage drivers](https://docs.docker.com/storage/storagedriver/) — how overlay2 works
