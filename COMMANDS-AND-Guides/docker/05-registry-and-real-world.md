# Docker — Part 05: Registry, Image Workflow, and Real-World Scenarios

---

## Docker Registries

A registry is where Docker images are stored and distributed. Think of it as GitHub for container images.

| Registry | Who Uses It | Free Tier |
|----------|------------|-----------|
| Docker Hub (`docker.io`) | Everyone, default | Yes (rate limited) |
| GitHub Container Registry (`ghcr.io`) | GitHub users | Yes |
| AWS ECR | AWS users | Yes (within same region) |
| Google Artifact Registry (`gcr.io`) | GCP users | Yes |
| Azure Container Registry | Azure users | No |
| Self-hosted (Harbor, Nexus) | On-prem teams | Yes |

---

## Pushing Images to Docker Hub

```bash
# 1. Login
docker login
# Enter username and password (or token)

# 2. Tag your image with your Docker Hub username
docker build -t vault-app:v1.0 .
docker tag vault-app:v1.0 yourusername/vault-app:v1.0
docker tag vault-app:v1.0 yourusername/vault-app:latest

# 3. Push
docker push yourusername/vault-app:v1.0
docker push yourusername/vault-app:latest

# 4. Pull from anywhere
docker pull yourusername/vault-app:v1.0
```

## Pushing to GitHub Container Registry (GHCR)

```bash
# 1. Create a Personal Access Token (PAT) with packages:write scope
# GitHub → Settings → Developer settings → Personal access tokens

# 2. Login
echo $GITHUB_TOKEN | docker login ghcr.io -u GITHUB_USERNAME --password-stdin

# 3. Tag and push
docker tag vault-app:v1.0 ghcr.io/GITHUB_USERNAME/vault-app:v1.0
docker push ghcr.io/GITHUB_USERNAME/vault-app:v1.0
```

## Pushing to AWS ECR

```bash
# 1. Authenticate (replace region and account ID)
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.ap-south-1.amazonaws.com

# 2. Create repository (first time only)
aws ecr create-repository --repository-name vault-app --region ap-south-1

# 3. Tag and push
docker tag vault-app:v1.0 123456789012.dkr.ecr.ap-south-1.amazonaws.com/vault-app:v1.0
docker push 123456789012.dkr.ecr.ap-south-1.amazonaws.com/vault-app:v1.0
```

---

## Complete CI/CD Image Build Pattern

```bash
# Typical in a CI pipeline (GitHub Actions, Jenkins, GitLab CI):

# Variables
IMAGE_NAME="ghcr.io/myorg/vault-app"
GIT_SHA=$(git rev-parse --short HEAD)
DATE=$(date +%Y%m%d)

# Build with multiple tags
docker build \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg GIT_COMMIT=$GIT_SHA \
  -t $IMAGE_NAME:$GIT_SHA \
  -t $IMAGE_NAME:latest \
  .

# Push all tags
docker push $IMAGE_NAME:$GIT_SHA
docker push $IMAGE_NAME:latest
```

---

## Docker Resource Limits

Prevent a single container from consuming all resources:

```bash
docker run -d \
  --name api \
  --memory 512m \           # max 512MB RAM
  --memory-swap 512m \      # disable swap (memory-swap == memory)
  --cpus 1.5 \              # max 1.5 CPU cores
  --pids-limit 100 \        # max 100 processes inside container
  vault-app:v1.0
```

In Docker Compose:

```yaml
services:
  api:
    image: vault-app:v1.0
    deploy:
      resources:
        limits:
          cpus: '1.5'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

---

## Docker Security Essentials

```bash
# 1. Run as non-root (in Dockerfile):
USER 1000

# 2. Read-only filesystem (write only to explicit volumes):
docker run --read-only -v /app/tmp:/tmp vault-app:v1.0

# 3. Drop Linux capabilities:
docker run --cap-drop ALL --cap-add NET_BIND_SERVICE vault-app:v1.0

# 4. Don't run privileged containers in production:
# docker run --privileged ...  ← almost always wrong

# 5. Scan images for vulnerabilities:
docker scout cves vault-app:v1.0    # Docker Desktop built-in
trivy image vault-app:v1.0          # trivy (open source)
```

---

## Useful Debugging Commands

```bash
# Get a shell even when the container has no shell (copy busybox in)
docker run -it --pid=container:brokenapp --net=container:brokenapp \
  busybox sh

# See all container resource usage
docker stats

# See container's network settings
docker inspect --format '{{.NetworkSettings.Networks}}' mycontainer

# See container's environment variables
docker inspect --format '{{.Config.Env}}' mycontainer

# See container's mounted volumes
docker inspect --format '{{.Mounts}}' mycontainer

# Follow container events in real time
docker events

# Export container filesystem as tar
docker export mycontainer > container.tar

# See image layers and sizes
docker history vault-app:v1.0
```

---

## Common Misunderstanding: "`latest` tag means the newest image"

**The misunderstanding:** "If I tag my image with `latest`, Docker will always pull the most recent version."

**The reality:** `latest` is just a regular tag — it has no special meaning to Docker. It only means "the newest version" if you consistently push to that tag. If you push `v1.0` and `v2.0` but only the first time you pushed `latest`, then `latest` is still pointing to `v1.0`.

**Problems with relying on `latest` in production:**
- `docker pull nginx` and `docker pull nginx:latest` pull the same thing — but "latest" can change under you if nginx releases a new version
- No reproducibility — two machines pulling `latest` on different days may get different images
- Kubernetes won't re-pull `latest` unless `imagePullPolicy: Always`

**Best practice:** Always pin to a specific version tag in production:
```yaml
image: nginx:1.24.0      # always this exact version
# not: image: nginx:latest
```

---

## Docker README

```
docker/
├── 00-core-concepts.md              ← Start here: VMs vs containers, image/container/Dockerfile
├── 01-installation-and-first-steps.md ← Install, docker run, ps, logs, exec
├── 02-dockerfile-and-building-images.md ← All Dockerfile instructions, multi-stage builds
├── 03-volumes-and-networking.md     ← Persistent storage, container networking, port mapping
├── 04-docker-compose.md             ← Multi-container apps, compose commands, env files
└── 05-registry-and-real-world.md    ← Pushing images, CI/CD patterns, security, debugging
```
