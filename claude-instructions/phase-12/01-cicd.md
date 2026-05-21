# Phase 12 — Step 1: CI/CD with GitHub Actions

## What this step covers
Build a CI/CD pipeline using GitHub Actions that runs on every push: tests the code, builds the Docker image, and deploys to the cloud environment.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/019-cicd-plan.md` first
- [ ] Explain what CI and CD are separately before showing the pipeline
- [ ] Write at least a few basic tests before setting up CI (otherwise CI has nothing to verify)

---

## Why this step exists

Manual deployments are:
- Slow (someone must be available to deploy)
- Error-prone (human mistakes)
- Undocumented (who deployed what, when, from which commit?)
- Inconsistent (dev env != CI env != prod env)

CI/CD automates this. Every code push:
1. Runs tests (CI — finds problems early)
2. Builds a Docker image
3. Pushes to a registry
4. Deploys to the cluster (CD — ships to production automatically)

This is the standard at every tech company with more than 5 engineers.

---

## What to implement

### Phase 12 prerequisite: Write basic tests first
Before CI, write minimal pytest tests:
- `tests/test_health.py` — test the health endpoint
- `tests/test_auth.py` — test register and login

These give CI something to actually run.

### GitHub Actions workflow: `.github/workflows/ci.yml`
Trigger: push to `main` or PR to `main`

Jobs:
1. **test** — run pytest
2. **build** — build Docker image, push to GitHub Container Registry (ghcr.io)
3. **deploy** — SSH into cloud server and run `helm upgrade`

```yaml
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install -r requirements.txt
      - run: pytest tests/ -v

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}/vault-api:${{ github.sha }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - run: |
          helm upgrade vault ./helm/vault \
            --set api.tag=${{ github.sha }}
```

### Secrets in GitHub
- `DEPLOY_SSH_KEY` — private key for SSH to cloud server
- Database credentials, SECRET_KEY — stored as GitHub Secrets, passed to workflows

---

## Concepts to teach during this step

- **CI (Continuous Integration)**: Every code push triggers automated tests. Problems are caught when the code is freshest in the developer's mind, not weeks later.

- **CD (Continuous Delivery/Deployment)**:
  - Delivery: every passing build is deployable (but someone presses a button)
  - Deployment: every passing build deploys automatically to production

- **GitHub Actions**: GitHub's built-in CI/CD. Workflow files in `.github/workflows/`. Triggered by events (push, PR, schedule, etc.).

- **Job dependencies (`needs`)**: `build` only runs if `test` passes. `deploy` only runs on `main`. Sequential safety.

- **GitHub Container Registry (ghcr.io)**: Free container registry built into GitHub. Images tagged with the commit SHA (`${{ github.sha }}`).

- **GitHub Secrets**: Sensitive values (API keys, SSH keys) stored encrypted in GitHub settings. Accessed in workflows as `${{ secrets.NAME }}`. Never in the code.

- **Why commit SHA as image tag**: Human-readable tags (`latest`, `v1.0`) can be overwritten. A commit SHA is immutable — you always know exactly which code is running.

- **Pipeline as code**: The CI/CD pipeline is a YAML file in the repo. It's version-controlled, reviewed in PRs, same as application code.

---

## Write tests before CI (mini step)

Teach pytest basics during this step:
- `pytest` discovers test files matching `test_*.py`
- Use `TestClient` from FastAPI to test endpoints without running a server
- Use a SQLite in-memory database for test isolation

Basic structure:
```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
```

---

## What NOT to do in this step

- Do NOT set up staging environments yet (keep it simple: CI tests + deploy to production)
- Do NOT add complex test coverage requirements
- Do NOT add canary deployments or blue-green
- Do NOT use paid CI/CD tools (GitHub Actions free tier is sufficient)

---

## File changes

| File | Action |
|---|---|
| `.github/workflows/ci.yml` | Create |
| `tests/test_health.py` | Create |
| `tests/test_auth.py` | Create |
| `tests/conftest.py` | Create — test database setup |

---

## Success criteria

1. Push to main → GitHub Actions tab shows pipeline running
2. `test` job: pytest passes, shown in workflow logs
3. `build` job: Docker image pushed to `ghcr.io/{repo}/vault-api:{sha}`
4. `deploy` job: Helm upgrade runs, new image deployed to cluster
5. A deliberate test failure (e.g., break health endpoint) → pipeline fails at `test` job, `deploy` never runs
