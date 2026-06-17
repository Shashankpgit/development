# GitHub Actions — Part 00: Mental Model

**20-minute read. Understand the architecture before writing a single YAML line.**

---

## What Is GitHub Actions?

GitHub Actions is a CI/CD platform built directly into GitHub. Every push, pull request, tag, or scheduled time can trigger automated work — testing code, building Docker images, deploying to production.

The key difference from Jenkins or CircleCI: **the pipeline lives in your repository** as a YAML file. No separate server to maintain. No plugin system to manage. The definition travels with the code.

---

## The Five Core Concepts

```
Repository
  └── Workflow           (.github/workflows/deploy.yml)
        └── Job          (a group of steps on ONE machine)
              └── Step   (one command or one action)
                    └── Action   (reusable unit of work from marketplace)
```

### Workflow
A YAML file in `.github/workflows/`. One repository can have multiple workflows. Each workflow is triggered by events (push, PR, schedule, manual).

### Job
A job is a collection of steps that runs on a single virtual machine (runner). Jobs run in **parallel by default** unless you add dependencies with `needs:`.

### Step
A step is one unit of work inside a job. It's either:
- A shell command (`run: npm test`)
- An action (`uses: actions/checkout@v4`)

Steps within a job run **sequentially**. If one fails, subsequent steps are skipped (unless you add `if: always()`).

### Action
An action is a reusable piece of logic — either from the GitHub Marketplace (`actions/checkout`), your own repository (`./my-action`), or a Docker image.

### Runner
The machine that executes your job. GitHub provides hosted runners (Ubuntu, Windows, macOS). You can also run your own (self-hosted runner).

---

## The Execution Model

```
Event occurs (push to main)
         │
         ▼
GitHub reads .github/workflows/*.yml
         │
         ▼
Matches trigger? → Start Workflow
         │
         ▼
┌────────────────────────────────────┐
│  Job: build            Job: test   │  ← run in PARALLEL
│  Step 1: checkout      Step 1: ... │
│  Step 2: npm install   Step 2: ... │
│  Step 3: npm build     Step 3: ... │
└────────────────────────────────────┘
         │  (both must pass)
         ▼
┌────────────────────────────────────┐
│  Job: deploy                       │  ← runs AFTER (needs: [build, test])
│  Step 1: Deploy to production      │
└────────────────────────────────────┘
```

Each job gets a **fresh virtual machine**. Nothing is shared between jobs automatically — you must explicitly pass data via **artifacts**.

---

## The Anatomy of a Workflow File

```yaml
# .github/workflows/ci.yml

name: CI Pipeline                      # Display name in GitHub UI

on:                                    # TRIGGER: what starts this workflow
  push:
    branches: [main, develop]          # only when pushing to these branches
  pull_request:
    branches: [main]                   # only for PRs targeting main

jobs:                                  # All jobs defined here

  test:                                # Job ID (used in needs:)
    name: Run Tests                    # Display name in GitHub UI
    runs-on: ubuntu-latest             # Which runner to use

    steps:                             # Sequential steps in this job

      - name: Checkout code            # Step display name
        uses: actions/checkout@v4      # Use an action from marketplace

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:                          # Parameters for the action
          node-version: '20'

      - name: Install dependencies
        run: npm ci                    # Run a shell command

      - name: Run tests
        run: npm test

  build:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: test                        # Wait for "test" job to succeed first

    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t vault-app:${{ github.sha }} .
```

---

## The `.github/workflows/` Directory

```
your-repo/
├── .github/
│   └── workflows/
│       ├── ci.yml           ← runs on every PR
│       ├── deploy-staging.yml  ← runs on push to develop
│       ├── deploy-prod.yml     ← runs on push to main
│       └── nightly.yml      ← runs on schedule
├── src/
├── Dockerfile
└── package.json
```

All `.yml` files in `.github/workflows/` are automatically discovered. No registration needed.

---

## GitHub Actions Context: What Information Is Available

During a workflow run, GitHub injects context variables you can reference with `${{ }}` syntax:

```yaml
# github context — information about the event and repo
${{ github.sha }}            # full git commit SHA: a3f7d2c...
${{ github.ref }}            # branch: refs/heads/main
${{ github.ref_name }}       # just the branch name: main
${{ github.repository }}     # owner/repo: sanketika/vault-app
${{ github.actor }}          # who triggered the run: shashank
${{ github.event_name }}     # push, pull_request, schedule, etc.
${{ github.run_id }}         # unique ID for this workflow run
${{ github.run_number }}     # incremental run count (1, 2, 3...)

# env context — environment variables
${{ env.MY_VARIABLE }}

# secrets context — encrypted secrets
${{ secrets.AWS_SECRET_KEY }}

# job context — current job status
${{ job.status }}            # success, failure, cancelled

# matrix context — matrix values (covered in file 04)
${{ matrix.node-version }}
```

---

## The Three Types of Triggers (Events)

### 1. Code Events (push, pull_request)
```yaml
on:
  push:
    branches: [main]
    paths:                   # only trigger when these files change
      - 'src/**'
      - 'Dockerfile'
    tags:
      - 'v*'                 # any tag starting with v (v1.0.0, v2.3.1)

  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]  # default: all three
```

### 2. Scheduled (cron)
```yaml
on:
  schedule:
    - cron: '0 2 * * *'     # every day at 2 AM UTC
    - cron: '0 8 * * 1'     # every Monday at 8 AM UTC
# GitHub cron syntax: minute hour day-of-month month day-of-week
```

### 3. Manual (workflow_dispatch)
```yaml
on:
  workflow_dispatch:          # adds a "Run workflow" button in GitHub UI
    inputs:
      environment:
        description: 'Deploy to which environment?'
        required: true
        default: 'staging'
        type: choice
        options: [staging, production]
      version:
        description: 'Version tag to deploy'
        required: true
        type: string
```

---

## Job Status and Conditions

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  notify-failure:
    runs-on: ubuntu-latest
    needs: test
    if: failure()             # only run if "test" job failed
    steps:
      - name: Send Slack alert
        run: echo "Tests failed!"

  always-cleanup:
    runs-on: ubuntu-latest
    needs: [test]
    if: always()              # run no matter what (success or failure)
    steps:
      - run: echo "Cleaning up"
```

Condition functions:
- `success()` — default when no `if:` is specified
- `failure()` — at least one previous job failed
- `cancelled()` — workflow was cancelled
- `always()` — run regardless of outcome

---

## Real-World Scenario: Why Jobs vs Steps Matters

**Wrong approach (everything in one job):**
```yaml
jobs:
  everything:
    runs-on: ubuntu-latest
    steps:
      - run: npm test
      - run: npm run lint
      - run: docker build .
      - run: docker push .
```
Problem: if lint fails, Docker build is skipped. But lint and tests could have run in parallel. And you're wasting time with sequential execution.

**Right approach (separate concerns):**
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  lint:
    runs-on: ubuntu-latest     # runs PARALLEL to test
    steps:
      - run: npm run lint

  build:
    runs-on: ubuntu-latest
    needs: [test, lint]        # wait for BOTH to pass
    steps:
      - run: docker build .

  deploy:
    runs-on: ubuntu-latest
    needs: build               # only if build passes
    steps:
      - run: ./deploy.sh
```

Result: test and lint run simultaneously. Total time = max(test_time, lint_time) + build_time, not test + lint + build.

---

## Common Misunderstanding: "GitHub Actions is just for CI"

**The misunderstanding:** GitHub Actions is for running tests on pull requests.

**The reality:** GitHub Actions can be triggered by ANY GitHub event:
- `issues` — auto-label issues, comment, close stale ones
- `release` — publish packages to npm/PyPI when a release is created
- `repository_dispatch` — triggered via API (external systems calling GitHub)
- `workflow_run` — trigger one workflow after another completes
- `deployment` — respond to deployment events from external systems
- `registry_package` — respond to package publishes

Many teams use GitHub Actions for:
- Nightly database backups
- Weekly dependency updates (Dependabot-style)
- Auto-generating changelogs on release
- Syncing secrets between environments
- Triggering Terraform plans on infrastructure changes

→ Continue to: `01-workflow-syntax.md`
