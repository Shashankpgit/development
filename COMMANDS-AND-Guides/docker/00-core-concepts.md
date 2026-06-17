# Docker — Part 00: Core Concepts (What Docker Is and How It Thinks)

Before running a single Docker command, you need the mental model. Without it, you will memorize commands but never understand WHY they behave the way they do.

---

## The Problem Docker Solves

Classic deployment problem: "It works on my machine."

You build an app on your laptop. It runs fine. You deploy it to the server. It crashes because the server has Python 3.8, your app needs Python 3.11, some library version is different, and a system dependency is missing.

Traditional solution: Write a 10-page setup document and hope the server admin follows it exactly.

**Docker's solution:** Package the app AND its entire environment (OS libraries, runtime, dependencies, config) into one portable unit called a **container**. The container runs identically everywhere — your laptop, a test server, a cloud VM — because it carries its environment with it.

---

## Containers vs Virtual Machines

This is the most important comparison to understand.

```
┌─────────────────────────────────┐    ┌─────────────────────────────────┐
│       VIRTUAL MACHINES          │    │          CONTAINERS              │
│                                 │    │                                  │
│  ┌──────┐ ┌──────┐ ┌──────┐    │    │  ┌──────┐ ┌──────┐ ┌──────┐    │
│  │ App A│ │ App B│ │ App C│    │    │  │ App A│ │ App B│ │ App C│    │
│  ├──────┤ ├──────┤ ├──────┤    │    │  ├──────┤ ├──────┤ ├──────┤    │
│  │Guest │ │Guest │ │Guest │    │    │  │Deps  │ │Deps  │ │Deps  │    │
│  │ OS   │ │ OS   │ │ OS   │    │    │  └──────┘ └──────┘ └──────┘    │
│  ├──────┴─┴──────┴─┴──────┤    │    │  ┌──────────────────────────┐   │
│  │      Hypervisor         │    │    │  │   Docker Engine (runtime)│   │
│  ├─────────────────────────┤    │    │  ├─────────────────────────┤    │
│  │       Host OS           │    │    │  │        Host OS           │    │
│  ├─────────────────────────┤    │    │  ├─────────────────────────┤    │
│  │       Hardware          │    │    │  │        Hardware          │    │
└─────────────────────────────────┘    └─────────────────────────────────┘
```

| | VMs | Containers |
|---|-----|------------|
| Size | GBs (includes full OS) | MBs (shares host OS kernel) |
| Startup time | Minutes | Seconds (or milliseconds) |
| Isolation | Complete (separate kernel) | Process-level (shared kernel) |
| Overhead | High | Very low |
| Use case | Full OS isolation needed | Application packaging |

**The key insight:** Containers share the HOST operating system's kernel. They don't boot a new OS — they just run isolated processes. This is why they start in seconds and use far less memory than VMs.

---

## The Three Core Building Blocks

### 1. Image — The Blueprint

A Docker image is a **read-only template** that contains:
- A base OS layer (e.g., Ubuntu, Alpine Linux)
- Runtime (Node.js, Python, Java)
- Your application code
- Dependencies (npm packages, pip packages)
- Configuration

Think of an image like a **class** in programming. It defines what something looks like but isn't running by itself.

Images are made of **layers**. Each instruction in a Dockerfile adds a layer. Layers are cached and shared — if two images share the same base OS layer, Docker stores that layer once on disk.

```
Image: vault-app:v1.0
│
├── Layer 1: ubuntu:22.04 (base OS)          ← 77MB
├── Layer 2: apt install nodejs               ← 45MB
├── Layer 3: npm install                      ← 120MB (from package.json)
├── Layer 4: COPY . /app                      ← 2MB (your code)
└── Layer 5: ENV NODE_ENV=production          ← 0KB (metadata only)
```

### 2. Container — The Running Instance

A container is a **running instance of an image**. Like an object is an instance of a class.

```
Image: vault-app:v1.0
         │
         ├──► Container 1 (vault-app-1, running, port 3000)
         ├──► Container 2 (vault-app-2, running, port 3001)
         └──► Container 3 (vault-app-3, stopped)
```

From ONE image you can create many containers. Each container:
- Has its own isolated filesystem (starts from the image but can write to a "container layer")
- Has its own isolated network namespace
- Has its own isolated process namespace
- Can be started, stopped, paused, and deleted independently

### 3. Dockerfile — The Recipe

A Dockerfile is a text file with instructions that tell Docker HOW to build an image.

```dockerfile
FROM node:18-alpine          # start from this base image
WORKDIR /app                 # set working directory inside container
COPY package*.json ./        # copy dependency files first (for caching)
RUN npm install              # install dependencies
COPY . .                     # copy the rest of your code
EXPOSE 3000                  # document which port the app uses
CMD ["node", "src/index.js"] # default command to run when container starts
```

---

## The Docker Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Your Machine (Docker Host)                    │
│                                                                  │
│  ┌──────────────┐    REST API    ┌──────────────────────────┐   │
│  │  Docker CLI  │ ─────────────► │    Docker Daemon         │   │
│  │  (docker)    │                │    (dockerd)             │   │
│  └──────────────┘                │                          │   │
│                                  │  ┌────────┐ ┌────────┐  │   │
│                                  │  │Cont. 1 │ │Cont. 2 │  │   │
│                                  │  └────────┘ └────────┘  │   │
│                                  │  Images cache            │   │
│                                  └──────────────────────────┘   │
│                                             │                    │
│                                             │ pull/push          │
└─────────────────────────────────────────────┼────────────────────┘
                                              │
                                    ┌─────────▼──────────┐
                                    │  Docker Registry    │
                                    │  (Docker Hub,       │
                                    │   ECR, GHCR, etc.)  │
                                    └────────────────────┘
```

- **Docker CLI** — the `docker` command you type in terminal
- **Docker Daemon (dockerd)** — background service that does the actual work
- **Registry** — remote storage for images (like GitHub for images)

When you run `docker pull nginx`, the CLI tells the daemon to fetch the `nginx` image from Docker Hub (the default registry).

---

## Container Lifecycle

```
               docker create
Image ──────────────────────────► Created
                                      │
                                docker start / docker run
                                      │
                                      ▼
                                   Running ◄──── docker unpause
                                      │               ▲
                                 docker pause         │
                                      │          docker unpause
                                      ▼
                                   Paused
                                      │
                                docker stop (SIGTERM → SIGKILL after timeout)
                                docker kill (immediate SIGKILL)
                                      │
                                      ▼
                                   Stopped
                                      │
                                 docker start (restart it)
                                 docker rm (delete it)
```

---

## Important Vocabulary

| Term | Meaning |
|------|---------|
| **Image** | Read-only template for creating containers |
| **Container** | Running instance of an image |
| **Dockerfile** | Instructions for building an image |
| **Registry** | Remote storage for images (Docker Hub, ECR, GHCR) |
| **Tag** | Version label on an image (`nginx:1.24`, `node:18-alpine`) |
| **Layer** | One step in an image's build history (each Dockerfile instruction) |
| **Volume** | Persistent storage that survives container restarts/deletion |
| **Bind mount** | Mount a specific host directory into the container |
| **Port mapping** | Connect a host port to a container port (`-p 8080:3000`) |
| **Network** | Virtual network connecting containers to each other |
| **Compose** | Tool for defining multi-container apps in a YAML file |

---

## Common Misunderstanding: "Containers are mini VMs"

**The misunderstanding:** "A container is just a small virtual machine."

**The reality:** A VM runs a complete separate operating system (full kernel + userspace). A container shares the host kernel and only isolates at the process level using Linux features called **namespaces** and **cgroups**:

- **Namespaces** — isolate what a process can see (filesystem, network, processes)
- **cgroups** — limit how much CPU/memory a process can use

A container is not a VM — it's a carefully isolated process. This is why:
- You can't run a Windows container on a Linux host (different kernels)
- Containers start in milliseconds (no OS boot)
- A container with no running process inside it stops immediately

→ Continue to: `01-installation-and-first-steps.md`
