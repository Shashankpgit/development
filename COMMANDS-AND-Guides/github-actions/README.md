# GitHub Actions — Complete Guide for DevOps Engineers

**7 files. ~20 minutes each. Zero to production CI/CD.**

---

## Reading Order

| File | Topic | What you'll be able to do |
|------|--------|--------------------------|
| [00-mental-model.md](00-mental-model.md) | Core concepts, anatomy, execution model | Understand how workflows, jobs, and steps fit together |
| [01-workflow-syntax.md](01-workflow-syntax.md) | Full YAML syntax, triggers, matrix, concurrency | Write any workflow from scratch |
| [02-actions-and-runners.md](02-actions-and-runners.md) | Marketplace actions, caching, artifacts | Use pre-built actions, make pipelines fast |
| [03-secrets-and-environments.md](03-secrets-and-environments.md) | Secrets, environments, OIDC auth | Authenticate to AWS/GCP/Azure without stored credentials |
| [04-ci-pipelines.md](04-ci-pipelines.md) | Complete CI for Node/Python/Go, matrix, security scans | Build real CI pipelines with tests, Docker, and scanning |
| [05-cd-deployments.md](05-cd-deployments.md) | Deploy to EKS/GKE/EC2, Helm, rollbacks | Full CD pipelines with approval gates and notifications |
| [06-advanced-patterns.md](06-advanced-patterns.md) | Reusable workflows, composite actions, debugging | Build reusable infrastructure, debug broken workflows |

---

## Quick Reference

### Workflow File Location
```
.github/workflows/ci.yml
.github/workflows/deploy.yml
```

### Minimal Working Workflow
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test
```

### Essential Context Variables
```yaml
${{ github.sha }}          # commit SHA
${{ github.ref_name }}     # branch name
${{ github.actor }}        # who triggered
${{ github.repository }}   # owner/repo
${{ github.event_name }}   # push, pull_request, etc.
${{ secrets.MY_SECRET }}   # a secret
${{ vars.MY_VAR }}         # a variable
${{ env.MY_ENV }}          # env var set in workflow
${{ inputs.MY_INPUT }}     # workflow_dispatch input
```

### Write to Special Files
```bash
# Set env var for subsequent steps:
echo "MY_VAR=value" >> $GITHUB_ENV

# Set step output:
echo "my-output=value" >> $GITHUB_OUTPUT

# Add to job summary (rendered markdown):
echo "## My Summary" >> $GITHUB_STEP_SUMMARY
```

---

## Triggers Cheatsheet

```yaml
# On push to main:
on:
  push:
    branches: [main]

# On PRs targeting main:
on:
  pull_request:
    branches: [main]

# On new version tags:
on:
  push:
    tags: ['v*']

# On schedule:
on:
  schedule:
    - cron: '0 2 * * *'   # daily at 2am UTC

# Manual with inputs:
on:
  workflow_dispatch:
    inputs:
      env:
        type: choice
        options: [staging, production]
```

---

## Must-Know Actions

| Action | Purpose |
|--------|---------|
| `actions/checkout@v4` | Clone repository |
| `actions/setup-node@v4` | Install Node.js |
| `actions/setup-python@v5` | Install Python |
| `actions/setup-go@v5` | Install Go |
| `actions/cache@v4` | Cache dependencies |
| `actions/upload-artifact@v4` | Save files between jobs |
| `actions/download-artifact@v4` | Restore saved files |
| `docker/setup-buildx-action@v3` | Enable Docker BuildKit |
| `docker/login-action@v3` | Login to container registry |
| `docker/build-push-action@v5` | Build and push Docker image |
| `docker/metadata-action@v5` | Auto-generate image tags |
| `aws-actions/configure-aws-credentials@v4` | AWS auth (OIDC or keys) |
| `google-github-actions/auth@v2` | GCP auth (OIDC) |
| `azure/login@v2` | Azure auth |
| `azure/setup-helm@v4` | Install Helm |
| `actions/github-script@v7` | Run JS to call GitHub API |

---

## Pattern Lookup

### Tests in CI with a database
→ Use `services:` block with health checks (see file 04)

### Deploy only on merge to main, not PRs
→ `if: github.event_name == 'push' && github.ref == 'refs/heads/main'`

### Require manual approval before production
→ Create a `production` environment with required reviewers, use `environment: production` on the job (see file 03)

### Authenticate to AWS without storing credentials
→ OIDC with `aws-actions/configure-aws-credentials@v4` + `permissions: id-token: write` (see file 03)

### Run tests for only changed services
→ Use `dorny/paths-filter@v3` to detect which paths changed, skip unchanged jobs (see file 04)

### Share a Docker image between CI (build) and CD (deploy) jobs
→ `outputs:` on the build job, `needs.build.outputs.image-tag` in deploy job (see file 01)

### Cancel duplicate runs on the same branch
→ `concurrency: group: ${{ github.ref }}` at workflow level (see file 01)

### Reuse deploy logic across repos
→ `workflow_call` trigger in a reusable workflow, `uses:` in the caller (see file 06)

---

## Common Error Messages

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `Context access might be invalid` | Typo in context variable name | Check spelling: `github.sha` not `github.SHA` |
| `Resource not accessible by integration` | `GITHUB_TOKEN` missing a permission | Add `permissions:` block to workflow or job |
| `Secret not found` | Secret name mismatch or wrong scope | Check Settings → Secrets; environment secrets need `environment:` on the job |
| `No hosted runner matches labels` | Typo in `runs-on` | Valid values: `ubuntu-latest`, `macos-latest`, `windows-latest` |
| `Error: Process completed with exit code 1` | A shell command failed | Check the step's logs; add `run: set -x` for verbose output |
| `Job exceeded the maximum execution time` | Infinite loop or hung process | Add `timeout-minutes:` to the job |
| `This workflow requires the permission id-token: write` | OIDC not enabled | Add `permissions: id-token: write` to the job |
