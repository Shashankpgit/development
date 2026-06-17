# GitHub Actions — Part 06: Advanced Patterns

**20-minute read. Reusable workflows, composite actions, self-hosted runners, debugging, and patterns that scale.**

---

## Reusable Workflows — DRY Across Repositories

Instead of copying the same deploy steps into every repository, define a workflow once and call it from others.

### The Reusable Workflow (Called Workflow)

```yaml
# .github/workflows/deploy-reusable.yml  (in your "platform" repo or same repo)

on:
  workflow_call:                   # this is what makes it reusable
    inputs:
      environment:
        required: true
        type: string
      image-tag:
        required: true
        type: string
      cluster-name:
        required: true
        type: string
    secrets:
      AWS_DEPLOY_ROLE:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    permissions:
      id-token: write
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE }}
          aws-region: ap-south-1

      - run: aws eks update-kubeconfig --name ${{ inputs.cluster-name }} --region ap-south-1

      - run: |
          kubectl set image deployment/app \
            app=ghcr.io/${{ github.repository }}:${{ inputs.image-tag }} \
            -n ${{ inputs.environment }}
          kubectl rollout status deployment/app -n ${{ inputs.environment }} --timeout=5m
```

### The Caller Workflow

```yaml
# .github/workflows/deploy.yml  (in your app repo)

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ github.sha }}
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t app:${{ github.sha }} .
      # ... push to registry

  deploy-staging:
    needs: build
    uses: ./.github/workflows/deploy-reusable.yml    # same repo
    # or from another repo:
    # uses: sanketika/platform/.github/workflows/deploy-reusable.yml@main
    with:
      environment: staging
      image-tag: ${{ github.sha }}
      cluster-name: vault-staging
    secrets:
      AWS_DEPLOY_ROLE: ${{ secrets.AWS_STAGING_ROLE }}

  deploy-production:
    needs: deploy-staging
    uses: ./.github/workflows/deploy-reusable.yml
    with:
      environment: production
      image-tag: ${{ github.sha }}
      cluster-name: vault-production
    secrets:
      AWS_DEPLOY_ROLE: ${{ secrets.AWS_PROD_ROLE }}
```

Benefits:
- One deploy definition, used by all repos
- Update the deploy logic once → all repos benefit
- Consistent deployment behavior across the organization

---

## Composite Actions — Reusable Step Groups

Composite actions are step sequences packaged as an action. Unlike reusable workflows (separate job), composite actions run inline in the current job.

### Creating a Composite Action

```yaml
# .github/actions/setup-and-cache/action.yml  (in your repo)

name: 'Setup Node with Cache'
description: 'Checkout, setup Node, and restore cache'

inputs:
  node-version:
    description: 'Node version to use'
    required: false
    default: '20'

outputs:
  cache-hit:
    description: 'Whether the cache was hit'
    value: ${{ steps.cache.outputs.cache-hit }}

runs:
  using: "composite"              # marks this as a composite action
  steps:
    - uses: actions/checkout@v4

    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}

    - uses: actions/cache@v4
      id: cache
      with:
        path: node_modules
        key: ${{ runner.os }}-modules-${{ hashFiles('package-lock.json') }}

    - name: Install dependencies
      if: steps.cache.outputs.cache-hit != 'true'
      run: npm ci
      shell: bash                 # required for composite action steps with `run:`
```

### Using the Composite Action

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: ./.github/actions/setup-and-cache   # path to action dir
        with:
          node-version: '20'
      
      - run: npm test               # node_modules already installed by the action
```

---

## Passing Secrets to Reusable Workflows: `inherit`

Instead of explicitly mapping every secret, use `secrets: inherit`:

```yaml
jobs:
  deploy:
    uses: ./.github/workflows/deploy-reusable.yml
    with:
      environment: production
      image-tag: ${{ github.sha }}
    secrets: inherit               # ALL caller secrets available in the called workflow
```

Use `inherit` for internal repos where you control both caller and called. For cross-org reuse, explicit secret mapping is safer.

---

## Workflow Dispatch — Triggering One Workflow from Another

```yaml
# Trigger another repository's workflow
- uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.PAT_TOKEN }}   # needs PAT with repo scope
    script: |
      await github.rest.actions.createWorkflowDispatch({
        owner: 'sanketika',
        repo: 'vault-infra',
        workflow_id: 'sync-configs.yml',
        ref: 'main',
        inputs: {
          version: '${{ github.sha }}'
        }
      })
```

---

## `workflow_run` — Trigger After Another Workflow Completes

```yaml
# deploy.yml — triggered when ci.yml completes successfully on main
on:
  workflow_run:
    workflows: ["CI Pipeline"]     # exact name from ci.yml
    branches: [main]
    types: [completed]             # completed (success or failure) / requested

jobs:
  deploy:
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success'   # only if CI passed
    steps:
      - run: echo "CI passed — deploying"
```

Why use this instead of `push`? `workflow_run` has access to the **base repo's secrets** even for PR runs, making it useful for deploying after PRs from forks.

---

## Job Outputs and Dynamic Workflows

```yaml
jobs:
  determine-deploy-targets:
    runs-on: ubuntu-latest
    outputs:
      targets: ${{ steps.targets.outputs.targets }}
    steps:
      - uses: actions/checkout@v4
      - id: targets
        run: |
          # Determine which services changed
          TARGETS=$(git diff --name-only HEAD~1 HEAD | \
            grep "^services/" | cut -d/ -f2 | sort -u | \
            jq -R -s -c 'split("\n")[:-1]')
          echo "targets=$TARGETS" >> $GITHUB_OUTPUT

  deploy:
    needs: determine-deploy-targets
    if: needs.determine-deploy-targets.outputs.targets != '[]'
    strategy:
      matrix:
        service: ${{ fromJSON(needs.determine-deploy-targets.outputs.targets) }}
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying ${{ matrix.service }}"
        # Only deploys changed services
```

---

## Debugging Workflows

### Debug Logging

```yaml
# Enable step debug logging (verbose)
# Repository → Settings → Secrets → Add secret:
# ACTIONS_STEP_DEBUG = true

# Enable runner diagnostic logging:
# ACTIONS_RUNNER_DEBUG = true

# Or pass at runtime (workflow_dispatch or API):
jobs:
  debug:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "github context:"
          echo '${{ toJSON(github) }}'

          echo "runner context:"
          echo '${{ toJSON(runner) }}'

          echo "env context:"
          echo '${{ toJSON(env) }}'
```

### Inspect the Runner Environment

```yaml
- name: List all env vars
  run: env | sort

- name: Check available tools
  run: |
    node --version
    python3 --version
    docker --version
    kubectl version --client
    aws --version
    which jq && jq --version

- name: Disk space
  run: df -h

- name: Running processes
  run: ps aux
```

### `tmate` — SSH into a Running Runner (For Debugging)

```yaml
- name: Debug — SSH session (ONLY for debugging, remove after!)
  uses: mxschmitt/action-tmate@v3
  if: failure()              # only open session if previous step failed
  timeout-minutes: 15        # auto-close after 15 minutes
```

This opens an SSH session into the runner. The action prints a connection string. Connect from your terminal and inspect the environment interactively.

---

## Step Summaries — Rich UI Output

```yaml
- name: Deployment Summary
  run: |
    echo "## 🚀 Deployment Summary" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "| Field | Value |" >> $GITHUB_STEP_SUMMARY
    echo "|-------|-------|" >> $GITHUB_STEP_SUMMARY
    echo "| Environment | production |" >> $GITHUB_STEP_SUMMARY
    echo "| Image Tag | \`${{ github.sha }}\` |" >> $GITHUB_STEP_SUMMARY
    echo "| Deployed By | ${{ github.actor }} |" >> $GITHUB_STEP_SUMMARY
    echo "| Trigger | ${{ github.event_name }} |" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "### Pods after deployment" >> $GITHUB_STEP_SUMMARY
    kubectl get pods -n production >> $GITHUB_STEP_SUMMARY
```

Visible in the workflow run page under the "Summary" tab.

---

## Keeping Workflows Maintainable

### Use `env:` at the Top for Repeated Values

```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
  NODE_VERSION: '20'
  CLUSTER_NAME: vault-cluster
  AWS_REGION: ap-south-1

jobs:
  build:
    steps:
      - run: docker build -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} .
```

### Group Related Workflows

```
.github/workflows/
  ci.yml                 → tests on every PR
  deploy-staging.yml     → deploy on push to develop
  deploy-production.yml  → deploy on push to main (or tag)
  release.yml            → create release, publish packages
  nightly.yml            → scheduled maintenance tasks
  pr-automation.yml      → label PRs, assign reviewers
```

---

## Real-World Pattern: GitOps with Image Tag Update

In GitOps, you don't deploy directly from CI. You update a manifest in a config repo, and ArgoCD/Flux picks up the change.

```yaml
# In application CI/CD:
- name: Update image tag in GitOps repo
  env:
    GH_TOKEN: ${{ secrets.GITOPS_PAT }}     # PAT with write access to config repo
  run: |
    # Clone the config/manifests repo
    git clone https://x-access-token:${GH_TOKEN}@github.com/sanketika/vault-k8s-configs.git
    cd vault-k8s-configs

    # Update the image tag (using yq or sed)
    yq e '.spec.template.spec.containers[0].image = "ghcr.io/sanketika/vault-app:${{ github.sha }}"' \
      -i deployments/production/vault-api.yaml

    # Commit and push
    git config user.email "ci@sanketika.in"
    git config user.name "GitHub Actions"
    git add deployments/production/vault-api.yaml
    git commit -m "chore: bump vault-api to ${{ github.sha }}"
    git push
```

ArgoCD watches the config repo. When it detects the change, it syncs the cluster. CI and CD are now fully decoupled.

---

## Common Misunderstanding: "Reusable workflows run in the same job"

**The misunderstanding:** "I'm calling a reusable workflow — its steps run in my current job."

**The reality:** A called reusable workflow runs as a **separate job** on a separate runner. This means:
- Files in `$GITHUB_WORKSPACE` are NOT shared with the caller — the runner starts fresh
- You cannot use `needs.job-id.outputs` from a called workflow step like you would a normal step
- Environment variables set with `$GITHUB_ENV` in the caller are NOT available in the called workflow

To pass data:
```yaml
# Pass via inputs (explicit):
uses: ./.github/workflows/deploy-reusable.yml
with:
  image-tag: ${{ github.sha }}

# Pass via secrets (explicit):
secrets:
  AWS_DEPLOY_ROLE: ${{ secrets.AWS_PROD_ROLE }}

# Or: secrets: inherit
```

The called workflow exposes `outputs:` at the job level, and the caller reads them via `needs.job-name.outputs.output-name`.

→ Continue to: `README.md`
