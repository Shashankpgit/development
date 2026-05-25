# 13 — Registry & Image Management

You've built images locally. Now you need to share them — push them to a registry so servers, teammates, and CI/CD pipelines can pull and run them.

---

## What Is a Registry?

A registry is a server that stores and distributes Docker images. It's like GitHub, but for images instead of code.

When you run `docker pull nginx`, Docker contacts the default registry (Docker Hub at `docker.io`), downloads the `nginx` image, and stores it locally. When you run `docker push myimage`, Docker uploads it to the registry.

```
Your machine ──push──► Registry ──pull──► Server / CI / Teammate
```

---

## Docker Hub

[hub.docker.com](https://hub.docker.com) is the default public registry. It hosts:

**Official images** — maintained by Docker or the software vendor:
- `postgres`, `redis`, `nginx`, `python`, `node`, `ubuntu`, `alpine`, `golang`
- Named without a namespace: `postgres:16`, `nginx:alpine`
- These are `library/postgres:16` under the hood — `library/` is the official namespace

**User/organization images** — uploaded by the community:
- Named with a namespace: `bitnami/redis`, `grafana/grafana`

**Your own images** — whatever you push:
- Named with your username: `yourusername/myapp:1.0`

**Free tier limits (as of 2024):**
- Unlimited public repositories
- 1 private repository
- Pull rate limits for unauthenticated pulls (100/6h), authenticated (200/6h)

---

## Image Naming — Full Anatomy

```
registry  / namespace / name    : tag
────────────────────────────────────────
docker.io / library  / postgres : 16
docker.io / ubuntu   / nginx    : 1.25-alpine
ghcr.io   / myorg    / myapp    : v2.1.0
```

When parts are omitted, Docker applies defaults:
- No registry → `docker.io`
- No namespace (for official images) → `library`
- No tag → `latest`

So `docker pull postgres` → `docker.io/library/postgres:latest`

---

## Logging In

Before pushing, authenticate:

```bash
# Docker Hub
docker login
# → prompts for username and password

# Docker Hub with credentials inline (for scripts/CI)
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

# GitHub Container Registry
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

# AWS ECR (uses AWS CLI to generate a temporary token)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-east-1.amazonaws.com
```

Credentials are stored in `~/.docker/config.json` (or OS keychain on Mac/Windows).

```bash
docker logout          # clear credentials
docker logout ghcr.io  # clear credentials for a specific registry
```

---

## Tagging Images

Tags are labels on images. One image can have multiple tags (like Git branches/tags pointing to the same commit).

```bash
# Tag when building
docker build -t myusername/myapp:1.0 .
docker build -t myusername/myapp:latest .

# Tag an existing image
docker tag myapp:1.0 myusername/myapp:1.0
docker tag myapp:1.0 myusername/myapp:latest    # same image, two tags
docker tag myapp:1.0 ghcr.io/myorg/myapp:1.0   # same image, different registry
```

**Tagging conventions:**

| Pattern | Example | Use for |
|---|---|---|
| Semantic version | `1.2.3` | Release builds |
| Major.minor | `1.2` | "latest of this minor version" |
| Major only | `1` | "latest of this major version" |
| `latest` | `latest` | Most recent stable build |
| Git SHA | `abc1234` | Specific commit (traceability) |
| Branch name | `main`, `develop` | Branch tracking |
| Environment | `production`, `staging` | Environment-specific builds |

**The `latest` tag danger:**

`latest` is just a convention. It means nothing special to Docker — it's a tag like any other. Problems with `latest`:
- When you pull `myimage:latest`, you don't know what version you're getting
- If the tag changes and someone pulls the new version, old containers may stop working
- You can't roll back by tag if everyone uses `latest`

**Rule:** In production, always pin a specific version. Use `latest` only for local development convenience.

---

## Pushing Images

```bash
# Tag (image must be tagged with registry/namespace/name)
docker tag myapp:1.0 myusername/myapp:1.0

# Push
docker push myusername/myapp:1.0

# Push all tags for this image
docker push myusername/myapp --all-tags
```

Docker pushes only the layers that don't already exist on the registry. If you built from `python:3.11-slim` and the registry already has those layers, only your custom layers are uploaded. This is why pushing is fast after the first time.

---

## Pulling Images

```bash
# Pull latest
docker pull nginx

# Pull a specific version
docker pull postgres:16

# Pull from GitHub Container Registry
docker pull ghcr.io/myorg/myapp:v2.1.0

# Pull and immediately run
docker run postgres:16   # pulls automatically if not local
```

---

## Inspecting Images

### docker image ls

```bash
docker image ls              # all local images
docker image ls postgres     # filter by name
docker images -a             # include intermediate layers
```

### docker image inspect

Full metadata — environment variables, exposed ports, entrypoint, layers, etc.:

```bash
docker image inspect postgres:16
docker image inspect postgres:16 --format '{{.Config.Env}}'    # just env vars
docker image inspect postgres:16 --format '{{.Config.ExposedPorts}}'
```

### docker image history

Show all layers and their sizes:

```bash
docker image history myapp:1.0
```

```
IMAGE         CREATED        CREATED BY                                SIZE
3f4a2b1e9c   2 minutes ago  CMD ["uvicorn", "app.main:app" ...]       0B
d1e2f3a4b5   2 minutes ago  COPY . .                                  2.1MB
8a7b6c5d4e   5 minutes ago  RUN pip install --no-cache-dir ...        89MB
...
```

**Security note:** `docker image history` shows every instruction that built an image, including build args. If a secret was passed via `ARG` or `RUN` with an inline secret, it may be visible here.

---

## GitHub Container Registry (ghcr.io)

GitHub's registry is free and tightly integrated with GitHub Actions:

```bash
# Login
echo "$GITHUB_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin

# Tag
docker tag myapp:1.0 ghcr.io/yourusername/myapp:1.0

# Push
docker push ghcr.io/yourusername/myapp:1.0
```

In GitHub Actions:
```yaml
- name: Log in to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}

- name: Build and push
  uses: docker/build-push-action@v5
  with:
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
```

---

## AWS Elastic Container Registry (ECR)

ECR is the standard for AWS deployments. It integrates with ECS, EKS, and CodePipeline.

```bash
# Authenticate (token valid for 12 hours)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Create a repository (one time)
aws ecr create-repository --repository-name myapp --region us-east-1

# Tag
docker tag myapp:1.0 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:1.0

# Push
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:1.0
```

---

## Image Security Scanning

### Docker Scout (free tier)

Docker Scout analyzes images for known CVEs (Common Vulnerabilities and Exposures):

```bash
# Scan a local image
docker scout cves myapp:1.0

# Quick summary
docker scout quickview myapp:1.0

# Compare against a base image
docker scout compare myapp:1.0 --to myapp:0.9
```

### Trivy (open source)

Trivy is a popular open-source vulnerability scanner:

```bash
# Install
brew install trivy        # Mac
apt install trivy         # Debian/Ubuntu

# Scan an image
trivy image myapp:1.0

# Scan and fail CI if HIGH or CRITICAL vulnerabilities found
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:1.0
```

Trivy checks:
- OS package vulnerabilities (apt, apk)
- Application dependencies (pip, npm, go modules, Maven)
- Misconfigurations
- Secrets accidentally baked in

---

## Cleaning Up Local Images

Images accumulate. Docker doesn't auto-delete them.

```bash
# Remove a specific image
docker rmi myapp:1.0
docker rmi myapp:1.0 myapp:latest

# Remove all dangling images (untagged, intermediate layers)
docker image prune

# Remove all unused images (not used by any container)
docker image prune -a

# Nuclear option — remove everything
docker system prune -a
```

**Dangling images:** Images with no tag (`<none>:<none>` in `docker images`). They accumulate when you rebuild without using `--no-cache` — the old layers become untagged.

---

## Multi-Platform Images

Docker images can be built for multiple CPU architectures (amd64, arm64). Useful for deploying to both x86 servers and ARM (Apple Silicon, Raspberry Pi, AWS Graviton).

```bash
# Build for multiple platforms and push in one step
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag myusername/myapp:1.0 \
  --push \
  .
```

The registry stores a "manifest list" — when someone pulls the image, Docker automatically picks the right architecture for their machine.

---

## Summary

- A registry stores and distributes images; Docker Hub is the default
- Image naming: `registry/namespace/name:tag` — defaults: `docker.io`, `library`, `latest`
- `docker login` before pushing; tag with registry path first
- Pin specific versions in production — never rely on `latest` being stable
- `docker image history` reveals every layer including potentially sensitive build args
- Scan images with Docker Scout or Trivy before deploying
- Use `docker image prune -a` to clean up unused local images

**Next:** [14 — Debugging & Troubleshooting](14-debugging-and-troubleshooting.md)

---

## Reference Links

- [Docker Hub](https://hub.docker.com) — the default registry
- [Docker Scout documentation](https://docs.docker.com/scout/)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Trivy vulnerability scanner](https://trivy.dev)
- [docker buildx for multi-platform](https://docs.docker.com/build/building/multi-platform/)
