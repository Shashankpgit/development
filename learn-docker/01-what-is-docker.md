# 01 — What is Docker?

Before any commands, any syntax — you need to understand *why Docker was built*. Every design decision in Docker traces back to the problem it was created to solve.

---

## The Problem: "It Works On My Machine"

Imagine you write a web application on your laptop. It works perfectly. You push it to a server. It crashes.

The server has:
- Python 3.8. Your laptop has Python 3.11.
- `libpq-dev` not installed. Your laptop has it.
- Ubuntu 22.04. Your laptop runs macOS 14.
- An environment variable set differently.

You spend hours debugging the server. You fix one thing, another breaks. Every teammate who clones the repo goes through the same pain.

This is called **dependency hell** — the software depends on a specific combination of OS libraries, language runtimes, system tools, and configuration that is slightly different on every machine.

**Docker solves this by packaging the application together with everything it needs to run, so it behaves identically on every machine.**

---

## What Docker Actually Is

Docker is a tool for building and running **containers**.

A container is a **process** running on Linux that is isolated from the rest of the system using two Linux kernel features:

1. **Namespaces** — give the process its own view of the filesystem, network, process list, and hostname. The process *thinks* it is the only thing running on the machine.

2. **Control Groups (cgroups)** — limit how much CPU, memory, and disk the process can consume.

That's it. A container is not a virtual machine. It is not a mini operating system. It is a process with restricted visibility and limited resources.

---

## VMs vs Containers

This comparison is the most important thing to understand before going further.

| | Virtual Machine | Container |
|---|---|---|
| What it runs on | Hypervisor (VMware, VirtualBox, KVM) | Docker Engine (uses host OS kernel directly) |
| Has its own OS kernel | Yes — full OS boots inside | No — shares the host kernel |
| Startup time | 30 seconds to several minutes | Under 1 second |
| Size | Gigabytes (full OS image) | Megabytes (just the app + its libraries) |
| Isolation level | Strong — separate kernel | Good — process-level (same kernel) |
| Overhead | High — full OS running inside | Low — just processes |
| Use case | Strong isolation, different OS types | Packaging, deployment, scaling apps |

**Analogy:**
- A VM is like renting a full apartment — your own kitchen, bathroom, everything.
- A container is like renting a room in a shared house — your own private space, but you share the plumbing and foundation.

**What this means practically:**
- You can start 100 containers on a laptop that can barely run 3 VMs.
- If you break the container, the host machine is unaffected (most of the time).
- All containers on a Linux host share the same Linux kernel — so Docker on Mac and Windows actually runs a lightweight Linux VM behind the scenes to provide that kernel.

---

## What a Container Is NOT

Clearing up common misconceptions:

**A container is not a VM.** It does not boot an operating system. It does not have a separate kernel. It uses the host's kernel through namespace isolation.

**A container is not always small.** A container image can be hundreds of MB if you start from a large base image and install a lot. Size is a choice, not a guarantee.

**A container is not automatically secure.** Containers share the host kernel. A kernel exploit can break out. Root inside a container is still dangerous. Security requires deliberate hardening (covered in [15-security-best-practices.md](15-security-best-practices.md)).

**A container is not a deployment strategy by itself.** Docker packages and runs. Orchestrating containers at scale (restarts, rolling deployments, scaling) requires Kubernetes or Docker Swarm.

---

## Core Vocabulary

You will see these terms everywhere. Learn them now.

| Term | Definition |
|---|---|
| **Image** | A read-only template — the packaged application + its dependencies + instructions. Like a class in OOP. |
| **Container** | A running instance of an image. Like an object instantiated from a class. |
| **Dockerfile** | A text file with step-by-step instructions for building an image. |
| **Registry** | A server that stores images. Docker Hub is the default public registry. |
| **Docker Hub** | The public registry at hub.docker.com. Where you pull postgres, nginx, python, etc. from. |
| **Docker Engine** | The background service (daemon) that builds images and runs containers. |
| **Docker CLI** | The `docker` command in your terminal. It talks to the daemon via a REST API. |
| **Layer** | Each instruction in a Dockerfile creates a layer. An image is a stack of layers. |
| **Volume** | Persistent storage attached to a container. Data in a volume survives container deletion. |
| **Compose** | A tool that runs multiple containers defined in a YAML file. |

---

## Why Docker Won (and Not Something Else)

Before Docker (2013), containers existed — LXC (Linux Containers) had been around since 2008. But LXC was hard to use. You had to understand Linux namespaces and cgroups directly.

Docker made containers accessible by:
1. Adding a simple image format (layers, built from a Dockerfile)
2. Adding a public registry (Docker Hub) so you could share images
3. Wrapping everything in a simple CLI (`docker run ubuntu`)

The packaging + distribution story is what made Docker ubiquitous. Not the container technology itself — that was already there. The tooling around it.

---

## What Docker Enables

**Consistent environments:** Build once, run anywhere. The same image runs on your laptop, your teammate's laptop, CI/CD, and production.

**Isolation without overhead:** Run PostgreSQL, Redis, and your app each in their own container without them interfering with each other — at a fraction of the cost of VMs.

**Reproducible builds:** A Dockerfile is a script. The same Dockerfile always produces the same image. No more "but it works when I build it manually".

**Fast onboarding:** A new teammate can go from zero to running the full application stack with two commands: `git clone` + `docker compose up`.

**Dependency version control:** Need Python 3.8 for one project and Python 3.11 for another? Run them simultaneously in separate containers. No virtualenv juggling.

---

## The Landscape (What Docker Is Not Responsible For)

Docker solves packaging and running. It does not solve:

- **Orchestration at scale** → Kubernetes, Docker Swarm
- **Service mesh / traffic management** → Istio, Linkerd
- **Serverless** → AWS Lambda, Google Cloud Run (though Cloud Run runs containers)
- **Image security scanning** → Trivy, Snyk, Docker Scout

Understanding where Docker ends and these other tools begin will save you from trying to solve orchestration problems with Docker features that were never designed for it.

---

## Summary

- Docker solves the "works on my machine" problem by packaging apps with their dependencies.
- Containers are isolated processes using Linux namespaces + cgroups — not VMs.
- VMs have a full OS kernel; containers share the host kernel. Containers are faster and lighter.
- Core vocabulary: image, container, Dockerfile, registry, layer, volume, compose.
- Docker won because it made containers easy to build and share — the packaging + distribution story.

**Next:** [02 — Installation & Setup](02-installation.md)

---

## Reference Links

- [Docker overview](https://docs.docker.com/get-started/overview/) — official introduction
- [What is a container?](https://www.docker.com/resources/what-container/) — Docker's own explanation
- [Linux namespaces](https://man7.org/linux/man-pages/man7/namespaces.7.html) — the kernel feature behind containers
- [cgroups](https://man7.org/linux/man-pages/man7/cgroups.7.html) — resource limiting for containers
