# 15 — Security Best Practices

A misconfigured container is worse than no container — it provides a false sense of isolation while exposing the host. This file covers the security decisions you need to make deliberately before going to production.

---

## The Threat Model

What are you protecting against with container security?

1. **Compromised application code** — a bug lets an attacker execute arbitrary commands
2. **Compromised supply chain** — a dependency or base image contains malicious code
3. **Secret leakage** — credentials end up in image layers, logs, or environment dumps
4. **Container escape** — an attacker compromises the container and finds a way to the host
5. **Over-privileged containers** — too many Linux capabilities mean a compromised container can do more damage

Container security is about limiting the blast radius of each of these.

---

## Run as Non-Root

By default, processes inside containers run as **root** (uid 0). Root inside a container is the same user ID as root on the host kernel. While container namespaces limit what root can see, kernel exploits can cross namespace boundaries.

```dockerfile
# Create a non-root user
RUN adduser --disabled-password --no-create-home --uid 1001 appuser

# Set ownership before switching user
RUN chown -R appuser:appuser /app

# Switch to non-root for all subsequent instructions including CMD
USER appuser
```

**Check what user your container is running as:**
```bash
docker exec mycontainer whoami
docker inspect mycontainer --format '{{.Config.User}}'
```

**Runtime override:**
```bash
docker run --user 1001:1001 myimage   # run as specific uid:gid
docker run --user nobody myimage      # use named user
```

---

## Use Minimal Base Images

Every package in your base image is a potential vulnerability. Use the smallest base that works.

| Base image | Size | Has shell? | OS packages |
|---|---|---|---|
| `ubuntu:22.04` | 77MB | bash | Full Ubuntu |
| `debian:bookworm-slim` | 76MB | bash | Minimal Debian |
| `alpine:3.19` | 7MB | sh | Minimal (musl) |
| `distroless/static` | 2MB | None | None |
| `scratch` | 0MB | None | None |

**Hierarchy of minimalism:**
1. `scratch` — for statically compiled Go/Rust binaries
2. `distroless` — for most compiled languages
3. `alpine` — for interpreted languages that need some OS libs
4. `slim` variants — for languages that need glibc compatibility
5. Full images — for development only

**Distroless images (Google):**
```dockerfile
FROM gcr.io/distroless/python3-debian12
```
No shell, no package manager, no OS utilities. An attacker who compromises the app cannot run shell commands. The trade-off: `docker exec -it container bash` won't work — use the builder stage for debugging.

---

## Never Bake Secrets Into Images

This cannot be overstated. Once a secret is in an image layer, it is permanent. Even if you `RUN rm secretfile` after copying it, the file exists in the previous layer.

```dockerfile
# ❌ NEVER DO THIS
ENV DB_PASSWORD=supersecret
ENV API_KEY=sk-live-...

# ❌ ALSO WRONG — the layer exists even if you delete the file
COPY .env /app/.env
RUN rm /app/.env
```

**Verification:** `docker image history myimage` shows every instruction. `docker save myimage | tar xf - | cat layer.tar | grep password` can extract secrets from layers.

**The correct approach:**
```yaml
# Pass secrets at runtime, never at build time
services:
  api:
    env_file:
      - ./backend/.env   # file on host, injected at runtime, never in image
```

**For build-time secrets** (private package registry tokens):
```dockerfile
RUN --mount=type=secret,id=pip_token \
    pip install --index-url https://token:$(cat /run/secrets/pip_token)@registry/simple/ \
    -r requirements.txt
```
```bash
docker build --secret id=pip_token,src=./pip_token.txt .
```
The secret is available during this RUN but never stored in any layer.

---

## Pin Image Versions

```dockerfile
# ❌ Unpinned — unpredictable, base image can change under you
FROM python:latest
FROM python:3.11

# ✅ Pinned by tag
FROM python:3.11-slim

# ✅✅ Pinned by digest — immutable (the most secure)
FROM python:3.11-slim@sha256:a1b2c3d4e5f6...
```

A pinned tag like `python:3.11-slim` is still mutable — someone could push a new `3.11-slim` to Docker Hub. A digest pin is immutable — it refers to exactly one image, forever.

**Get a digest:**
```bash
docker pull python:3.11-slim
docker inspect python:3.11-slim --format '{{.Id}}'
# → sha256:a1b2c3d4...
```

---

## Scan Images for Vulnerabilities

Run a scanner before every production deployment.

**Trivy (recommended, open source):**
```bash
# Install
brew install trivy

# Scan an image
trivy image myapp:1.0

# Fail CI if HIGH or CRITICAL CVEs found
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:1.0

# Scan a running container
trivy image $(docker inspect mycontainer --format '{{.Image}}')
```

**Docker Scout:**
```bash
docker scout cves myapp:1.0
docker scout quickview myapp:1.0
```

**In CI (GitHub Actions with Trivy):**
```yaml
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: myapp:${{ github.sha }}
    exit-code: '1'
    severity: 'HIGH,CRITICAL'
```

---

## Drop Linux Capabilities

Linux capabilities are fine-grained permissions that root has. Even non-root containers may inherit some. You can drop them all and add back only what's needed.

```bash
# Drop all capabilities (most restrictive)
docker run --cap-drop=ALL myimage

# Drop all, add back only what you need
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myimage
# NET_BIND_SERVICE lets you bind to ports < 1024 (like 80)
```

In docker-compose:
```yaml
services:
  api:
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE   # only if you bind to port 80/443 directly
```

**Capabilities you should almost never need:**
- `SYS_ADMIN` — if a container needs this, question why
- `NET_ADMIN` — network configuration privileges
- `SYS_PTRACE` — ability to trace processes (can be used for container escape)

---

## Read-Only Filesystem

Prevent the container from writing to its own filesystem:

```bash
docker run --read-only myimage
```

In compose:
```yaml
services:
  api:
    read_only: true
    tmpfs:
      - /tmp        # apps that need to write temp files get a tmpfs
      - /app/tmp
```

A read-only filesystem means:
- Malware cannot install itself or modify binaries
- An attacker can't write persistent tools or scripts
- Configuration can't be tampered with at runtime

Most web apps only write to temp files, logs (stdout), and database. Read-only is achievable.

---

## Don't Run Privileged Containers

```bash
# ❌ NEVER in production
docker run --privileged myimage
```

`--privileged` grants the container nearly all Linux capabilities and full access to host devices. It effectively removes container isolation for privileged operations. A compromised privileged container is a compromised host.

If you see `--privileged` in a production setup, it's a red flag. Most legitimate uses (like Docker-in-Docker) have safer alternatives.

---

## Limit Resources

Prevent a single container from consuming all host resources (DoS, noisy neighbor):

```bash
docker run --memory=512m --cpus=1.0 myimage
```

In compose:
```yaml
services:
  api:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 256M
          cpus: '0.5'
```

---

## Keep the Attack Surface Small

### .dockerignore — prevent secrets entering the build context
Always exclude `.env`, `.git`, IDE files. (See [06-build-context-and-ignore.md](06-build-context-and-ignore.md))

### Don't install unnecessary tools
Every debugging tool you install is something an attacker could use. No curl, wget, or shell tools in production images unless required.

```dockerfile
# Install only what the app needs, then remove build tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq5 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

`--no-install-recommends` prevents apt from installing suggested packages that you didn't explicitly ask for.

### Expose only necessary ports
Compose: only add `ports:` for services that genuinely need external access. Internal services (databases, queues) should have no exposed ports.

---

## Network Isolation with Multiple Networks

Separate services by what they need to communicate with:

```yaml
networks:
  internet_facing:    # nginx only — faces the internet
  app_tier:           # nginx + api — api isn't directly internet-exposed
  data_tier:          # api + db + redis — data layer, never internet-exposed

services:
  nginx:
    networks: [internet_facing, app_tier]
  api:
    networks: [app_tier, data_tier]
  db:
    networks: [data_tier]   # only api can reach db
  redis:
    networks: [data_tier]
```

Even if nginx is compromised, the attacker can't reach the database directly — it's on a different network that nginx isn't connected to.

---

## Security Checklist

Before deploying to production:

- [ ] Container runs as non-root user (USER instruction in Dockerfile)
- [ ] Base image uses `slim` or `alpine` variant (not full OS)
- [ ] No secrets in Dockerfile (no hardcoded passwords, no `COPY .env`)
- [ ] `.env` file is in `.dockerignore`
- [ ] Image version is pinned (not `latest`)
- [ ] Image has been scanned with Trivy or Docker Scout
- [ ] Linux capabilities are dropped (`cap_drop: ALL`)
- [ ] No `--privileged` flag
- [ ] No sensitive ports exposed unnecessarily
- [ ] Memory and CPU limits are set
- [ ] Read-only filesystem enabled (or restricted to tmpfs writes only)
- [ ] Multiple compose networks to isolate service tiers

---

## Summary

- Run as non-root — add `USER` instruction to every production Dockerfile
- Use minimal base images — `slim`, `alpine`, or `distroless`
- Never bake secrets into images — inject at runtime via `env_file:`
- Pin base image versions — tags are mutable, digests are not
- Scan with Trivy or Docker Scout before every deployment
- Drop all Linux capabilities; add back only what's needed
- No `--privileged`, no unnecessary exposed ports, no unnecessary OS tools
- Use multiple compose networks to isolate service tiers

**Next:** [16 — Production Checklist](16-production-checklist.md)

---

## Reference Links

- [Docker security documentation](https://docs.docker.com/engine/security/)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Trivy vulnerability scanner](https://trivy.dev)
- [Linux capabilities man page](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Distroless images](https://github.com/GoogleContainerTools/distroless)
- [Docker Content Trust (image signing)](https://docs.docker.com/engine/security/trust/)
