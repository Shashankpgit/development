# Docker — Complete Learning Guide

A ground-up curriculum to take you from "what is Docker?" to production-ready containerisation. Every concept is explained from first principles — not just *what* to type, but *why* it works the way it does.

---

## Who This Is For

- Developers who have never used Docker before
- People who can run `docker run` but don't understand what is actually happening
- Anyone preparing to deploy a real application using containers

**Prerequisites:** Basic Linux command line comfort (cd, ls, cat, grep). You do not need to know anything about Docker.

---

## Learning Path

Read the files in this order. Each file builds on the previous one.

| # | File | What You Learn | Est. Time |
|---|---|---|---|
| 1 | [What is Docker?](01-what-is-docker.md) | Why Docker exists, VMs vs containers, core vocabulary | 20 min |
| 2 | [Installation & Setup](02-installation.md) | Install Docker on Linux / Mac / Windows, verify it works | 15 min |
| 3 | [Core Concepts](03-core-concepts.md) | Images, containers, registry, daemon — the mental model | 25 min |
| 4 | [Essential CLI Commands](04-essential-cli-commands.md) | Every command you will use daily, with flags explained | 30 min |
| 5 | [Dockerfile](05-dockerfile.md) | Write Dockerfiles, all instructions, layer system | 45 min |
| 6 | [Build Context & .dockerignore](06-build-context-and-ignore.md) | What gets sent to Docker, how to exclude files | 15 min |
| 7 | [Layer Cache Optimization](07-layer-cache-optimization.md) | Make builds fast, understand cache invalidation | 20 min |
| 8 | [Volumes & Data Persistence](08-volumes.md) | Keep data alive across container restarts | 25 min |
| 9 | [Networking](09-networking.md) | How containers talk to each other and the outside world | 30 min |
| 10 | [Docker Compose](10-docker-compose.md) | Run multi-container applications with one command | 40 min |
| 11 | [Environment Variables & Secrets](11-environment-variables.md) | Inject config at runtime, never bake secrets into images | 20 min |
| 12 | [Multi-Stage Builds](12-multi-stage-builds.md) | Shrink production images dramatically | 20 min |
| 13 | [Registry & Image Management](13-registry-and-images.md) | Push and pull images, Docker Hub, tagging | 20 min |
| 14 | [Debugging & Troubleshooting](14-debugging-and-troubleshooting.md) | Inspect, exec, logs — fix anything that goes wrong | 30 min |
| 15 | [Security Best Practices](15-security-best-practices.md) | Run containers safely in production | 25 min |
| 16 | [Production Checklist](16-production-checklist.md) | Everything together — a real-world hardened setup | 30 min |

**Total estimated time:** ~6 hours of reading + hands-on practice

---

## How to Use This Guide

1. **Read in order** — later files assume knowledge from earlier ones
2. **Run every command yourself** — reading without practice does not stick
3. **Break things deliberately** — when a gotcha section describes something, reproduce the error, then fix it
4. **Come back to reference sections** — the CLI cheat sheets and comparison tables are meant to be re-read

---

## Docker Version Used

This guide was written against **Docker CE 25.x / Docker Compose v2**. Commands use `docker compose` (V2, with a space), not `docker-compose` (V1, with a hyphen). On older systems you may need the hyphen form.

Check your version:
```bash
docker version
docker compose version
```

---

## Official Reference Links

- [Docker Documentation](https://docs.docker.com) — the authoritative source
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/) — every instruction
- [Docker Compose reference](https://docs.docker.com/compose/compose-file/) — every compose field
- [Docker Hub](https://hub.docker.com) — the default image registry
- [Play with Docker](https://labs.play-with-docker.com) — free browser-based Docker playground
