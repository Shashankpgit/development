# KT 20 — GitHub Actions

## What GitHub Actions is

GitHub Actions is GitHub's built-in automation platform. You write instructions in a YAML file — GitHub runs them automatically when something happens (a push, a PR, a schedule).

Before GitHub Actions, teams used separate tools: Jenkins, CircleCI, Travis CI. All of these required running a separate server just to run automation. GitHub Actions runs the automation on GitHub's own servers — no extra setup.

---

## The mental model

```
Event happens (push to main)
        ↓
GitHub reads .github/workflows/*.yml
        ↓
Spins up a fresh virtual machine (called a "runner")
        ↓
Runs your jobs/steps on that VM
        ↓
VM is destroyed when done
```

Every workflow run gets a **brand new, clean machine**. Nothing carries over between runs. This is intentional — it prevents "works on my machine" problems.

---

## Core concepts

### Workflow
A YAML file inside `.github/workflows/`. One workflow = one automated process.

You can have multiple workflows:
```
.github/workflows/
├── build-images.yml     ← builds and pushes Docker images
├── run-tests.yml        ← runs pytest on every PR
└── deploy.yml           ← deploys to GKE on push to main
```

### Event (trigger)
What causes the workflow to run.

```yaml
on:
  push:
    branches: [main]           # runs when you push to main
    paths:
      - 'vault/backend/**'     # only if these files changed

  pull_request:
    branches: [main]           # runs when a PR targets main

  schedule:
    - cron: '0 0 * * *'        # runs every day at midnight (UTC)

  workflow_dispatch:           # adds a manual "Run workflow" button in GitHub UI
```

`paths` is powerful: if you only change frontend code, the backend image doesn't need to rebuild. GitHub Actions skips the workflow if no matching paths changed.

### Job
A workflow contains one or more jobs. Each job runs on its own runner (VM). Jobs run **in parallel by default**.

```yaml
jobs:
  build-api:          # job 1 — runs in parallel with build-frontend
    runs-on: ubuntu-latest
    steps: [...]

  build-frontend:     # job 2 — runs in parallel with build-api
    runs-on: ubuntu-latest
    steps: [...]

  deploy:
    needs: [build-api, build-frontend]   # waits for both to finish
    runs-on: ubuntu-latest
    steps: [...]
```

### Runner
The VM that runs your job. `ubuntu-latest` is the most common — a fresh Ubuntu machine with common tools pre-installed (Docker, git, Python, Node, etc.).

GitHub provides these runners for free (with limits). You can also self-host runners on your own machines.

### Step
The actual commands inside a job. Steps run **sequentially** within a job — one at a time.

```yaml
steps:
  - name: Checkout code         # step 1
    uses: actions/checkout@v4

  - name: Build Docker image    # step 2 (runs after step 1)
    run: docker build -t myimage .

  - name: Push to GHCR         # step 3 (runs after step 2)
    run: docker push myimage
```

### `uses` vs `run`

Two ways to write a step:

```yaml
# uses: runs a pre-built Action (someone else's code)
- uses: actions/checkout@v4          # checks out your repo
- uses: docker/login-action@v3       # logs into a container registry

# run: runs a shell command directly
- run: echo "hello"
- run: docker build -t myimage .
- run: |
    echo "line 1"
    echo "line 2"
```

`uses` actions are reusable building blocks published on the GitHub Marketplace. You use them instead of writing complex shell scripts.

---

## Actions in depth

An **Action** is a pre-built, reusable step. Think of it like a pip package but for CI/CD steps.

Common actions you'll use:

| Action | What it does |
|---|---|
| `actions/checkout@v4` | Clones your repo onto the runner |
| `actions/setup-python@v5` | Installs a specific Python version |
| `docker/login-action@v3` | Logs into a container registry |
| `docker/build-push-action@v5` | Builds and pushes a Docker image |
| `azure/setup-helm@v3` | Installs Helm on the runner |
| `google-github-actions/auth@v2` | Authenticates with GCP |

The `@v4` is a version tag — always pin versions so a breaking change in an action doesn't silently break your pipeline.

---

## Secrets

Workflows often need sensitive values: passwords, API keys, SSH keys. You never put these in the YAML file (it's in git — anyone can see it).

GitHub Secrets: encrypted values stored in GitHub settings. Injected into workflows at runtime.

**Set a secret:**
GitHub repo → Settings → Secrets and variables → Actions → New repository secret

**Use in workflow:**
```yaml
- name: Login to GHCR
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

`${{ secrets.GITHUB_TOKEN }}` is a **special automatic secret** — GitHub creates it for every workflow run automatically. It has permissions to push to GHCR for the same repo. You don't need to create it.

For other secrets you create yourself:
```yaml
password: ${{ secrets.MY_CUSTOM_SECRET }}
```

---

## Context variables

GitHub provides built-in variables with information about the current run:

| Variable | Value |
|---|---|
| `${{ github.sha }}` | The full git commit SHA (e.g. `abc1234...`) |
| `${{ github.ref }}` | The branch/tag ref (e.g. `refs/heads/main`) |
| `${{ github.actor }}` | The GitHub username that triggered the run |
| `${{ github.repository }}` | `owner/repo-name` |
| `${{ github.repository_owner }}` | Just the `owner` part |
| `${{ github.event_name }}` | What triggered it: `push`, `pull_request`, etc. |

These are used to tag Docker images, set deployment targets, etc.:
```yaml
tags: ghcr.io/${{ github.repository_owner }}/vault-api:${{ github.sha }}
```

---

## Environment variables

You can define env vars at workflow, job, or step level:

```yaml
env:                                    # workflow-level (all jobs)
  REGISTRY: ghcr.io

jobs:
  build:
    env:                                # job-level (all steps in this job)
      IMAGE_NAME: vault-api

    steps:
      - run: echo "Building $IMAGE_NAME"
        env:                            # step-level (this step only)
          DEBUG: true
```

---

## Conditions

Run a job or step only when a condition is true:

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'   # only deploy on main, not on PRs
```

```yaml
steps:
  - name: Notify on failure
    if: failure()                          # only runs if a previous step failed
    run: echo "Something went wrong"
```

---

## A complete workflow — reading it top to bottom

```yaml
name: Build and Push Images          # shown in GitHub Actions tab

on:
  push:
    branches: [main]                 # trigger: push to main
    paths:
      - 'vault/backend/**'           # only if backend files changed

jobs:
  build-api:                         # job name
    runs-on: ubuntu-latest           # fresh Ubuntu VM

    permissions:
      contents: read                 # read the repo
      packages: write                # push to GHCR

    steps:
      - name: Checkout code          # step 1: clone repo to runner
        uses: actions/checkout@v4

      - name: Login to GHCR          # step 2: authenticate
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push         # step 3: build image + push
        uses: docker/build-push-action@v5
        with:
          context: ./vault/backend
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/vault-api:${{ github.sha }}
            ghcr.io/${{ github.repository_owner }}/vault-api:latest
```

Reading this: "When someone pushes to `main` and backend files changed → spin up Ubuntu → clone the repo → log into GHCR → build the backend Docker image → push it tagged with the commit SHA."

---

## What the runner has pre-installed

You don't need to install Docker, git, curl, Python, Node on the runner. They come pre-installed on `ubuntu-latest`. Full list: https://github.com/actions/runner-images

---

## Where workflows live in our repo

```
development/
└── .github/
    └── workflows/
        ├── build-backend.yml     ← builds vault-api image on backend changes
        └── build-frontend.yml    ← builds vault-nginx image on frontend changes
```

These run on GitHub's servers — you never need to do anything manually to build images again after this is set up.

---

## Summary — the flow we will build

```
You push code to vault/backend/
        ↓
GitHub sees the push, matches build-backend.yml trigger
        ↓
GitHub spins up a fresh Ubuntu VM
        ↓
Runner: clones repo → logs into GHCR → docker build → docker push
        ↓
Image available at ghcr.io/username/vault-api:abc1234
        ↓
GKE can now pull this image
```

Once you understand this, we write the actual workflow files.
