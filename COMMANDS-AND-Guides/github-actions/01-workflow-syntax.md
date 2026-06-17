# GitHub Actions — Part 01: Workflow Syntax Deep Dive

**20-minute read. Master every YAML keyword you'll use in real workflows.**

---

## Full Workflow Structure

```yaml
name: string                    # workflow display name
run-name: string                # custom run display name (supports expressions)

on: ...                         # triggers

defaults:                       # defaults applied to all jobs
  run:
    shell: bash
    working-directory: ./app

env:                            # env vars available to ALL jobs
  NODE_ENV: production
  APP_PORT: 3000

concurrency:                    # prevent parallel runs of the same workflow
  group: deploy-${{ github.ref }}
  cancel-in-progress: true

jobs:
  job-id:
    name: string
    runs-on: string | array
    needs: [job-id, ...]
    if: expression
    environment: string
    concurrency: ...
    timeout-minutes: number
    continue-on-error: boolean
    strategy: ...
    env: ...
    outputs: ...
    steps: [...]
```

---

## Triggers: `on` In Depth

### push and pull_request Filters

```yaml
on:
  push:
    branches:
      - main
      - 'release/**'       # wildcard: release/1.0, release/2.3
      - '!hotfix/**'       # exclude branches matching this (! = negate)
    branches-ignore:
      - 'wip/**'
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'   # semantic version tags: v1.2.3
    paths:
      - 'src/**'
      - 'package.json'
      - '!docs/**'         # ignore docs changes
    paths-ignore:
      - '**.md'            # never trigger on .md file changes

  pull_request:
    branches: [main]
    types:
      - opened             # new PR created
      - synchronize        # new commits pushed to PR
      - reopened           # closed PR reopened
      - ready_for_review   # converted from draft to ready
      # (by default: opened, synchronize, reopened)
```

### workflow_dispatch (Manual Trigger)

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [staging, production]
      dry_run:
        description: 'Dry run only?'
        required: false
        type: boolean
        default: false
      tag:
        description: 'Image tag to deploy'
        required: true
        type: string

# Access in steps:
# ${{ inputs.environment }}
# ${{ inputs.dry_run }}
# ${{ inputs.tag }}
```

### Multiple Events

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * 0'    # every Sunday midnight UTC
  workflow_dispatch:         # manual trigger
```

---

## Jobs Deep Dive

### Defining Jobs

```yaml
jobs:
  build:
    name: Build Application
    runs-on: ubuntu-latest
    timeout-minutes: 30       # kill job if it runs too long (prevents infinite loops)
    continue-on-error: false  # default: failure stops later steps

    steps:
      - uses: actions/checkout@v4
```

### Job Dependencies

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint

  build:
    runs-on: ubuntu-latest
    needs: [test, lint]       # both must succeed
    steps:
      - run: docker build .

  deploy-staging:
    runs-on: ubuntu-latest
    needs: build              # single dependency
    steps:
      - run: ./deploy.sh staging

  deploy-prod:
    runs-on: ubuntu-latest
    needs: [build, deploy-staging]
    steps:
      - run: ./deploy.sh production
```

### Passing Data Between Jobs (Outputs)

Jobs run on separate machines. Pass data using `outputs`:

```yaml
jobs:
  set-version:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.get-version.outputs.version }}  # expose step output as job output
    steps:
      - uses: actions/checkout@v4
      - id: get-version
        run: echo "version=$(cat VERSION)" >> $GITHUB_OUTPUT
        # $GITHUB_OUTPUT is a file — anything written to it becomes a step output

  build:
    runs-on: ubuntu-latest
    needs: set-version
    steps:
      - run: echo "Building version ${{ needs.set-version.outputs.version }}"
      # needs.<job-id>.outputs.<output-name>
```

---

## Runners

### GitHub-Hosted Runners

```yaml
runs-on: ubuntu-latest      # Ubuntu 22.04
runs-on: ubuntu-22.04       # specific version (more predictable)
runs-on: ubuntu-20.04
runs-on: windows-latest
runs-on: macos-latest
runs-on: macos-14           # Apple Silicon M1

# Larger runners (paid plans):
runs-on: ubuntu-latest-4-cores
runs-on: ubuntu-latest-8-cores
```

GitHub-hosted runners come pre-installed with common tools: git, Node.js, Python, Java, Docker, kubectl, aws-cli, az CLI, gcloud.

```bash
# See what's installed on ubuntu-latest:
# https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2204-Readme.md
```

### Self-Hosted Runners

```yaml
runs-on: self-hosted          # use any self-hosted runner
runs-on: [self-hosted, linux, x64]  # label-based selection
runs-on: [self-hosted, production]  # custom label
```

---

## Steps Deep Dive

### run: Shell Commands

```yaml
steps:
  - name: Single line
    run: npm test

  - name: Multi-line
    run: |
      npm ci
      npm run build
      npm test

  - name: With custom shell
    shell: python
    run: |
      import json
      print(json.dumps({"status": "ok"}))

  - name: With working directory
    working-directory: ./backend
    run: npm ci

  - name: With environment variables (scoped to this step)
    env:
      DATABASE_URL: ${{ secrets.DATABASE_URL }}
      NODE_ENV: test
    run: npm test
```

### Setting Environment Variables for Subsequent Steps

```yaml
steps:
  - name: Set variable
    run: echo "IMAGE_TAG=v$(date +%Y%m%d)-${{ github.sha }}" >> $GITHUB_ENV
    # $GITHUB_ENV is a file — anything written becomes available as ${{ env.VARIABLE }}

  - name: Use the variable
    run: docker build -t vault-app:${{ env.IMAGE_TAG }} .
```

### Setting Step Outputs

```yaml
steps:
  - id: check-changes
    run: |
      if git diff --name-only HEAD~1 HEAD | grep -q "^src/"; then
        echo "changed=true" >> $GITHUB_OUTPUT
      else
        echo "changed=false" >> $GITHUB_OUTPUT
      fi

  - name: Run tests only if code changed
    if: steps.check-changes.outputs.changed == 'true'
    run: npm test
```

---

## Expressions and Conditionals

### `if:` Conditions on Jobs and Steps

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'   # only run on main branch

    steps:
      - name: Deploy to production
        if: github.event_name == 'push'   # not on PRs

      - name: Notify Slack
        if: failure()                      # only on failure

      - name: Always cleanup
        if: always()
```

### Operators in Expressions

```yaml
# Comparison
if: github.ref == 'refs/heads/main'
if: github.ref != 'refs/heads/main'
if: github.run_number > 5

# Logical
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
if: "!contains(github.ref, 'hotfix')"   # NOT

# Functions
if: contains(github.ref, 'release')      # string contains check
if: startsWith(github.ref, 'refs/tags/') # starts with
if: endsWith(github.ref, '/main')
```

### The `format()` Function

```yaml
- name: Tag Docker image
  run: docker tag vault-app:latest ${{ format('{0}/vault-app:{1}', env.REGISTRY, github.sha) }}
```

---

## Strategy: Matrix Builds

Run the same job with different combinations of variables.

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        node: [18, 20, 22]
        # Creates 6 jobs: all combinations of os × node

      fail-fast: false   # default true: if one fails, cancel the rest
                         # false: let all combinations run even if one fails

      max-parallel: 3    # run at most 3 at a time

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm test

  # Matrix with include (add extra combinations):
  test-extended:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node: [18, 20]
        include:
          - node: 18
            experimental: false
          - node: 22                   # add a combination not in the base matrix
            experimental: true
      exclude:
        - os: macos-latest
          node: 18                     # skip this specific combination
```

---

## Environment Variables — All Sources

```yaml
# Order of precedence (highest first):
# 1. Step-level env
# 2. Job-level env
# 3. Workflow-level env
# 4. Runner's system env

env:                          # workflow-level
  REGISTRY: ghcr.io

jobs:
  build:
    env:                      # job-level (overrides workflow-level for this job)
      BUILDKIT_INLINE_CACHE: '1'
    steps:
      - env:                  # step-level (overrides all)
          NODE_ENV: test
        run: npm test

# Special env variables (set automatically by GitHub):
# GITHUB_SHA          — commit SHA
# GITHUB_REF          — branch/tag ref
# GITHUB_REPOSITORY   — owner/repo
# GITHUB_WORKSPACE    — path to checked-out repo on runner
# GITHUB_ENV          — path to env file (write here to set env for next steps)
# GITHUB_OUTPUT       — path to output file (write here to set step outputs)
# GITHUB_STEP_SUMMARY — path to step summary file (write markdown here for UI)
```

---

## Job Summary — Rich Output in GitHub UI

```yaml
steps:
  - name: Generate test summary
    run: |
      echo "## Test Results" >> $GITHUB_STEP_SUMMARY
      echo "" >> $GITHUB_STEP_SUMMARY
      echo "| Test Suite | Status | Duration |" >> $GITHUB_STEP_SUMMARY
      echo "|-----------|--------|----------|" >> $GITHUB_STEP_SUMMARY
      echo "| Unit Tests | ✅ Passed | 12s |" >> $GITHUB_STEP_SUMMARY
      echo "| Integration | ✅ Passed | 45s |" >> $GITHUB_STEP_SUMMARY
```

This renders as a markdown table in the workflow summary page — useful for test reports, deployment summaries, or showing which artifacts were built.

---

## Concurrency — Prevent Duplicate Deployments

```yaml
# At workflow level: cancel any in-progress run on same branch when a new one starts
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

# At job level:
jobs:
  deploy:
    concurrency:
      group: deploy-production   # only one deploy-production job at a time globally
      cancel-in-progress: false  # don't cancel: queue instead (safer for deploys)
```

Without concurrency control: you push twice quickly → two deploy jobs run simultaneously → second deploy might overwrite first's in-progress state, corrupting production.

---

## Real-World Scenario: PR-Only vs Main-Only Steps

```yaml
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        run: npm test                 # always runs

      - name: Build production image
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: docker build -t vault-app:${{ github.sha }} .

      - name: Push to registry
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: docker push vault-app:${{ github.sha }}

      - name: Deploy to production
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: ./deploy.sh production ${{ github.sha }}
```

On a PR: only tests run. On merge to main: tests + build + push + deploy.

---

## Common Misunderstanding: `branches: [main]` in push vs pull_request

**The misunderstanding:** "I set `branches: [main]` so this workflow runs when I push to main."

**The reality:** The behavior differs between `push` and `pull_request`:
- `push.branches: [main]` → triggers when you directly push TO the `main` branch
- `pull_request.branches: [main]` → triggers on PRs whose **target** is `main` (the PR could be from any branch)

```yaml
on:
  push:
    branches: [main]         # triggers on: git push origin main
  pull_request:
    branches: [main]         # triggers on: opening a PR that will merge INTO main
                             # NOT on PRs targeting develop
```

A PR from `feature/login` to `main` triggers `pull_request`, not `push`. A direct commit to `main` triggers `push`, not `pull_request`. They're completely separate events.

→ Continue to: `02-actions-and-runners.md`
