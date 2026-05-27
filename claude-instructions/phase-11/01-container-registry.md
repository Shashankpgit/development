# Phase 11 — Container Registry (GHCR)

## What this phase covers

Build Docker images for the vault app and push them to GitHub Container Registry (ghcr.io). Tag images with git commit SHA. Update Helm chart values to pull from the registry. This is the prerequisite for everything else — Helm needs an image to pull, CI/CD needs somewhere to push.

---

## Pre-step checklist

- [ ] Create `docs/plans/019-container-registry-plan.md` first
- [ ] minikube running (Phase 10 complete)
- [ ] GitHub account with access to the repo

---

## Why this phase exists

In development (docker-compose), images are built locally:
```yaml
build: ./backend
```
Docker builds the image on your machine and uses it immediately.

In Kubernetes, pods run across machines — possibly machines that have never seen your code. Every machine needs to pull the image from a central location. That central location is a **container registry**.

The flow in production:
```
Your code → docker build → docker push → registry
                                              ↓
                                    K8s pulls on every node
```

---

## What is GHCR

GitHub Container Registry (`ghcr.io`) is a free container registry built into GitHub.

- Images live at: `ghcr.io/<github-username>/<image-name>:<tag>`
- Access controlled by GitHub PAT (Personal Access Token)
- Private by default, can be made public
- Free for public repos, included in GitHub free tier for private

Why GHCR over Docker Hub: it's in the same place as your code (GitHub), auth is handled by GitHub tokens, and it integrates naturally with GitHub Actions CI/CD.

---

## Image tagging strategy

```
ghcr.io/your-username/vault-api:latest         ← BAD: "latest" is mutable
ghcr.io/your-username/vault-api:v1.0.0         ← OK: semantic version, but manual
ghcr.io/your-username/vault-api:abc1234        ← BEST: git commit SHA
```

**Why git SHA is the right tag:**
- Immutable: once pushed, that tag always points to that exact code
- Traceable: you can always know exactly which commit is running in production
- Automated: CI/CD can set it with `${{ github.sha }}` — no human decision needed

For local development, we'll use `latest` to keep it simple. In CI/CD (Phase 14), we switch to SHA tags automatically.

---

## What to implement

### Step 1 — Authenticate to GHCR

```bash
# Generate a PAT at: GitHub → Settings → Developer Settings → Personal Access Tokens → Fine-grained
# Required scopes: read:packages, write:packages

export GITHUB_TOKEN=your_pat_here
export GITHUB_USERNAME=your_github_username

echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
# Login Succeeded
```

### Step 2 — Build and tag images with registry prefix

The registry is encoded into the image tag. Docker uses the prefix to know where to push.

```bash
# Backend
docker build \
  -t ghcr.io/$GITHUB_USERNAME/vault-api:latest \
  ./vault/backend

# Frontend + nginx (combined in one image, same as docker-compose)
docker build \
  -t ghcr.io/$GITHUB_USERNAME/vault-nginx:latest \
  -f ./vault/nginx/Dockerfile \
  ./vault
```

Note: the nginx Dockerfile builds the React frontend and serves it from nginx. One image, two things.

### Step 3 — Push to GHCR

```bash
docker push ghcr.io/$GITHUB_USERNAME/vault-api:latest
docker push ghcr.io/$GITHUB_USERNAME/vault-nginx:latest
```

Visit `https://github.com/YOUR_USERNAME?tab=packages` — both images should appear.

### Step 4 — Make images public (for simplicity in local minikube)

In GitHub → your package → Package settings → Change visibility → Public

This means minikube can pull without credentials. For production (Phase 15), we'll use imagePullSecrets.

### Step 5 — Load images into minikube

Even though images are in GHCR, for local development you can also load them directly:

```bash
minikube image load ghcr.io/$GITHUB_USERNAME/vault-api:latest
minikube image load ghcr.io/$GITHUB_USERNAME/vault-nginx:latest

# Verify
minikube image ls | grep vault
```

Using the registry is better practice (same flow as production). Loading directly is faster for iteration during local development.

---

## The Keycloak and Kong images

For Keycloak and Kong, we do NOT push custom images. We use the official images:
- `quay.io/keycloak/keycloak:24.0` — official Keycloak
- `kong:3.7` — official Kong

Our custom configuration (realm-export.json, kong.yml) is not baked into images. It's passed in as ConfigMaps and mounted as files. This is the correct K8s pattern: **images are code, configuration is separate**.

---

## Deliberate mistake for this step

**Mistake**: Build the image without the `ghcr.io/username/` prefix, then try to push.

```bash
docker build -t vault-api:latest ./vault/backend
docker push vault-api:latest
# Error: denied: requested access to the resource is denied
# OR: push refers to repository [docker.io/library/vault-api]
```

**Lesson**: Docker uses the image name to determine the target registry. `vault-api:latest` defaults to Docker Hub's public library. `ghcr.io/username/vault-api:latest` targets GHCR. The registry is part of the tag — not a separate parameter.

---

## Success criteria

```bash
# Images exist in GHCR
# https://github.com/YOUR_USERNAME?tab=packages → vault-api, vault-nginx visible

# Images can be pulled
docker pull ghcr.io/$GITHUB_USERNAME/vault-api:latest
# → Pull complete

# minikube can run the image
kubectl run test-api \
  --image=ghcr.io/$GITHUB_USERNAME/vault-api:latest \
  -n default \
  -- sh -c "echo ok"
kubectl logs test-api
# → ok
kubectl delete pod test-api
```

Images are in GHCR. Ready for Phase 12: write Helm charts.
