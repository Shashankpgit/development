# Phase 14 — CI/CD with GitHub Actions

## What this phase covers

Build a CI/CD pipeline using GitHub Actions. On every push to `main`: run tests, build Docker images tagged with git SHA, push to GHCR, deploy to the cluster via `helm upgrade`.

---

## Pre-step checklist

- [ ] Create `docs/plans/022-cicd-plan.md` first
- [ ] Phase 13 complete: full stack running in minikube
- [ ] Write basic tests first — CI needs something to verify

---

## Why CI/CD

Manual deployments are:
- Slow — someone must be available
- Error-prone — "works on my machine"
- Untraceable — who deployed what, from which commit, when?

CI/CD automates the entire path from `git push` to running in production:
1. **CI (Continuous Integration)**: every push runs tests, catches problems early
2. **CD (Continuous Deployment)**: every passing build ships automatically

---

## Step 1 — Write tests first

CI with no tests just builds and deploys untested code. Write minimal pytest tests before the pipeline:

`vault/backend/tests/test_health.py`:
```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
```

`vault/backend/tests/test_notes.py`:
```python
def test_create_note_requires_auth():
    response = client.post("/notes", json={"title": "test"})
    assert response.status_code == 401
```

Run locally first:
```bash
cd vault/backend
pip install pytest httpx
pytest tests/ -v
```

---

## Step 2 — GitHub Actions workflow

`.github/workflows/ci.yml`:

```yaml
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_PREFIX: ghcr.io/${{ github.repository_owner }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: pip install -r vault/backend/requirements.txt pytest httpx

      - name: Run tests
        run: pytest vault/backend/tests/ -v

  build-and-push:
    needs: test                      # only runs if test passes
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'   # only on main, not PRs

    permissions:
      contents: read
      packages: write                # needed to push to GHCR

    steps:
      - uses: actions/checkout@v4

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}   # automatic, no setup needed

      - name: Build and push vault-api
        uses: docker/build-push-action@v5
        with:
          context: ./vault/backend
          push: true
          tags: |
            ${{ env.IMAGE_PREFIX }}/vault-api:${{ github.sha }}
            ${{ env.IMAGE_PREFIX }}/vault-api:latest

      - name: Build and push vault-nginx
        uses: docker/build-push-action@v5
        with:
          context: ./vault
          file: ./vault/nginx/Dockerfile
          push: true
          tags: |
            ${{ env.IMAGE_PREFIX }}/vault-nginx:${{ github.sha }}
            ${{ env.IMAGE_PREFIX }}/vault-nginx:latest

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Install Helm
        uses: azure/setup-helm@v3

      - name: Deploy to cluster
        run: |
          helm upgrade --install vault helm/vault/ \
            --namespace vault \
            --set vault-api.image.tag=${{ github.sha }} \
            --set vault-nginx.image.tag=${{ github.sha }}
        # Note: kubeconfig setup depends on which cluster (minikube vs GKE)
        # For GKE this will use a service account key stored as a GitHub Secret
```

---

## Concepts to understand

### `needs` — job dependency
Without `needs: test`, all jobs run in parallel. `build-and-push` would push a broken image before tests even finish. `needs` enforces order and gates: deploy never runs if test fails.

### `${{ github.sha }}` — commit SHA as image tag
The SHA uniquely identifies the exact commit that produced this image. You can always look at a running pod's image tag and know exactly which commit it's running. `latest` gives you no such guarantee.

### `GITHUB_TOKEN` — automatic secret
GitHub automatically injects this token with permissions scoped to the repo. For pushing to GHCR, it has `packages: write` permission. You don't create this secret — GitHub provides it.

### `if: github.ref == 'refs/heads/main'`
Build and deploy only on commits to `main`. On pull requests: only run tests. This prevents deploying every feature branch.

---

## GitHub Secrets to add

For the deploy step to reach the cluster (when you move to GKE in Phase 15):

| Secret name | Value |
|---|---|
| `GKE_SA_KEY` | GKE service account JSON key |
| `GKE_PROJECT` | GCP project ID |
| `GKE_CLUSTER` | GKE cluster name |
| `GKE_REGION` | GCP region |

For minikube (local), the deploy step won't work from GitHub Actions (no access to your laptop). The minikube deploy is manual. The pipeline tests and builds — that's already valuable.

---

## Deliberate mistake for this step

**Mistake**: Remove `needs: test` from the `build-and-push` job.

```yaml
build-and-push:
  # needs: test  ← removed
  runs-on: ubuntu-latest
```

Break a test intentionally. Observe: build runs in parallel with tests, push succeeds, deploy runs. Broken code ships.

**Lesson**: `needs` is what makes CI/CD safe. Without it, CI/CD is just a fast way to deploy broken code. Every job in a deploy pipeline should have `needs` pointing to the job before it.

---

## Success criteria

```bash
# Push a commit to main
git push origin main

# GitHub Actions tab shows:
# test → build-and-push → deploy
# All green

# Deliberate failure: break a test, push, observe:
# test → FAILED
# build-and-push → SKIPPED (never ran)
# deploy → SKIPPED

# Image in GHCR tagged with commit SHA
# ghcr.io/YOUR_USERNAME/vault-api:abc1234 exists
```
