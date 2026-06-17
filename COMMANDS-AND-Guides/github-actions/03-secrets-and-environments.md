# GitHub Actions — Part 03: Secrets, Environments, and OIDC Auth

**20-minute read. The right way to handle credentials — including the modern approach that eliminates stored cloud secrets entirely.**

---

## Secrets vs Variables

GitHub gives you two types of stored values:

| Type | Encrypted | Visible in logs | Use for |
|------|-----------|-----------------|---------|
| **Secret** | Yes | Never (masked) | passwords, tokens, keys |
| **Variable** | No | Yes | non-sensitive config values |

```yaml
# Using a secret
- run: docker login -u ${{ secrets.DOCKERHUB_USERNAME }} -p ${{ secrets.DOCKERHUB_TOKEN }}

# Using a variable
- run: echo "Deploying to ${{ vars.DEPLOY_REGION }}"
```

Secrets are masked in logs — if you accidentally `echo` a secret, GitHub replaces it with `***`. Variables appear in plain text.

---

## Secret Scopes

GitHub secrets exist at three levels:

```
Organization level secrets
  └── Repository level secrets
        └── Environment level secrets (staging, production)
```

- **Organization secrets**: available to multiple repositories (managed by org admins)
- **Repository secrets**: available to all workflows in that repo
- **Environment secrets**: only available when a job targets that specific environment

### Setting Secrets

```bash
# Via GitHub CLI:
gh secret set AWS_SECRET_KEY --body "your-secret-value"
gh secret set AWS_SECRET_KEY --env production --body "prod-value"

# List secrets (names only, not values):
gh secret list
gh secret list --env production

# Delete:
gh secret delete AWS_SECRET_KEY
```

Or: Repository → Settings → Secrets and variables → Actions

---

## The `GITHUB_TOKEN` — The Built-In Secret

Every workflow run automatically gets a `GITHUB_TOKEN` with no setup required. It's a short-lived token scoped to your repository.

```yaml
- name: Create GitHub Release
  uses: actions/create-release@v1
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}   # built-in, always available
```

Default permissions (`GITHUB_TOKEN`):
- Read: contents, issues, packages, pull-requests
- Write: nothing by default (you must grant it)

### Granting More Permissions

```yaml
name: Release

on:
  push:
    tags: ['v*']

permissions:                  # workflow-level permissions
  contents: write             # needed to create releases and push commits
  packages: write             # needed to push to GHCR
  pull-requests: write        # needed to comment on PRs

jobs:
  release:
    permissions:              # job-level (more precise)
      contents: write
      packages: write
    runs-on: ubuntu-latest
    steps:
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}  # no extra token needed for GHCR
```

---

## Environments — Deployment Gating

Environments add protection rules to jobs. A job targeting an environment can require:
- Manual approval before running
- Specific branches to deploy
- A wait timer

### Create an Environment

```
Repository → Settings → Environments → New environment
```

```yaml
# In workflow:
jobs:
  deploy-production:
    runs-on: ubuntu-latest
    environment: production        # target this environment
    steps:
      - run: ./deploy.sh production
```

When `environment: production` is set:
- GitHub checks if the current branch is allowed to deploy to this environment
- If approval is required, the job pauses and sends a notification to reviewers
- Reviewers click Approve in the GitHub UI → job resumes
- Secrets scoped to `production` environment are now available

### Environment with Variables and Secrets

```yaml
jobs:
  deploy:
    environment: production        # access production environment's secrets/vars
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "Deploying to ${{ vars.APP_URL }}"    # environment variable
          ./deploy.sh ${{ secrets.DEPLOY_KEY }}       # environment secret
```

Each environment (staging, production) can have different values for the same variable/secret name. The job gets the right value based on `environment:`.

### Multiple Environment Deployments

```yaml
jobs:
  deploy-staging:
    environment: staging
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh ${{ vars.CLUSTER_NAME }}    # staging cluster name

  deploy-prod:
    needs: deploy-staging
    environment: production          # different secrets, requires approval
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh ${{ vars.CLUSTER_NAME }}    # production cluster name
```

---

## OIDC — The Modern Way to Authenticate with Cloud Providers

**Problem with traditional approach:**
```yaml
# OLD WAY — storing long-lived credentials in GitHub secrets
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

Problems:
- Credentials can be stolen if secrets are exfiltrated
- Keys never expire (unless manually rotated)
- Keys have the same permissions regardless of which branch runs

**OIDC Solution:** Instead of storing credentials, GitHub proves its identity to AWS/GCP/Azure using a signed JWT token. AWS grants a temporary role (valid for 1 hour) in response.

```
GitHub Actions run
    │
    │ "I am github.com/sanketika/vault-app, running on main branch"
    │ (signed by GitHub's OIDC provider)
    ▼
AWS STS (Security Token Service)
    │
    │ "I trust GitHub's OIDC — here's a temporary role with ECR push access"
    │ (valid for 1 hour)
    ▼
Workflow uses temporary credentials
```

### OIDC with AWS

#### Step 1: Set up AWS OIDC Provider (one-time, in AWS console or Terraform)

```bash
# AWS CLI
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --client-id-list sts.amazonaws.com
```

#### Step 2: Create an IAM Role with Trust Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:sanketika/vault-app:*"
          // Or restrict to specific branch:
          // "repo:sanketika/vault-app:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Attach permissions to this role (e.g., ECR push, EKS access). No access key needed.

#### Step 3: Use in Workflow — No Stored Credentials

```yaml
name: Deploy

on:
  push:
    branches: [main]

permissions:
  id-token: write      # REQUIRED for OIDC — allows GitHub to request the JWT
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-vault-deploy
          aws-region: ap-south-1
          # No access key ID or secret key — just the role ARN

      - name: Push to ECR
        run: |
          aws ecr get-login-password --region ap-south-1 \
            | docker login --username AWS --password-stdin 123456789.dkr.ecr.ap-south-1.amazonaws.com
          docker build -t vault-app .
          docker tag vault-app:latest 123456789.dkr.ecr.ap-south-1.amazonaws.com/vault-app:${{ github.sha }}
          docker push 123456789.dkr.ecr.ap-south-1.amazonaws.com/vault-app:${{ github.sha }}

      - name: Update EKS Deployment
        run: |
          aws eks update-kubeconfig --name vault-cluster --region ap-south-1
          kubectl set image deployment/vault-api vault-api=123456789.dkr.ecr.ap-south-1.amazonaws.com/vault-app:${{ github.sha }}
```

### OIDC with GCP

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: 'projects/123456/locations/global/workloadIdentityPools/github/providers/github-actions'
      service_account: 'github-actions@my-project.iam.gserviceaccount.com'
      # No service account key file stored in secrets

  - uses: google-github-actions/setup-gcloud@v2

  - run: |
      gcloud auth configure-docker asia-south1-docker.pkg.dev
      docker push asia-south1-docker.pkg.dev/my-project/vault-app:${{ github.sha }}
```

### OIDC with Azure

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      # Still stores 3 IDs (not secrets), but no passwords or certificates
      # These are not sensitive — they're just identifiers
```

---

## Preventing Secret Leaks

### Mask Custom Values in Logs

```yaml
- name: Mask derived secrets
  run: |
    DYNAMIC_TOKEN=$(./get-token.sh)
    echo "::add-mask::$DYNAMIC_TOKEN"    # mask this value in all subsequent logs
    echo "TOKEN=$DYNAMIC_TOKEN" >> $GITHUB_ENV
```

### Never Do This

```yaml
# NEVER: prints secret to log
- run: echo "My secret is ${{ secrets.API_KEY }}"

# NEVER: puts secret in an arg that shows in process list
- run: ./deploy.sh --password ${{ secrets.DB_PASSWORD }}
# Use stdin or env vars instead:
- run: ./deploy.sh
  env:
    DB_PASSWORD: ${{ secrets.DB_PASSWORD }}

# NEVER: writes secrets to artifacts
- uses: actions/upload-artifact@v4
  with:
    path: .env       # if .env contains secrets, they become downloadable
```

---

## Real-World Scenario: Different Secrets per Environment

You have staging and production with different database passwords and API keys.

```
Environment: staging
  Secrets: DATABASE_URL = postgres://staging-server/...
           STRIPE_KEY   = sk_test_...
  Variables: APP_URL = https://staging.vault.example.com

Environment: production
  Secrets: DATABASE_URL = postgres://prod-server/...
           STRIPE_KEY   = sk_live_...
  Variables: APP_URL = https://vault.example.com
```

```yaml
jobs:
  deploy-staging:
    environment: staging
    runs-on: ubuntu-latest
    steps:
      - run: |
          export DATABASE_URL="${{ secrets.DATABASE_URL }}"   # staging DB
          export STRIPE_KEY="${{ secrets.STRIPE_KEY }}"       # test key
          kubectl create secret generic app-secrets \
            --from-literal=database-url="$DATABASE_URL" \
            --from-literal=stripe-key="$STRIPE_KEY" \
            --dry-run=client -o yaml | kubectl apply -f -

  deploy-prod:
    environment: production      # approval gate + different secrets
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - run: |
          export DATABASE_URL="${{ secrets.DATABASE_URL }}"   # prod DB
          export STRIPE_KEY="${{ secrets.STRIPE_KEY }}"       # live key
          kubectl create secret generic app-secrets ...
```

Same YAML, different secrets automatically. The environment name is the only change.

---

## Common Misunderstanding: "Forked PR workflows can access my secrets"

**The misunderstanding:** "A PR from a fork runs my workflow — can it steal my secrets?"

**The reality:** For security, `pull_request` events from **forks** do NOT have access to secrets. The workflow runs in a read-only context with no write permissions and no secrets available.

GitHub provides `pull_request_target` which runs in the context of the base repo (has access to secrets) — but this is dangerous for untrusted PRs since it runs the contributor's code with your secrets. Never use `pull_request_target` for running user code.

The correct pattern for fork PRs:
1. `pull_request` triggers a workflow that runs tests (no secrets needed — use public images, mock services)
2. A repository maintainer reviews and approves the PR
3. On merge (now a `push` event), the full workflow with secrets runs

```yaml
# Safe: tests don't need secrets
on: pull_request
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test              # no secrets needed here
```

→ Continue to: `04-ci-pipelines.md`
