# GitHub Actions — Part 05: CD — Deploying to Real Infrastructure

**20-minute read. Deploy to EKS, GKE, EC2, and with Helm. Approval gates. Rollbacks.**

---

## CD Architecture Overview

```
push to main
     │
     ▼
CI Workflow passes (tests + build + push image)
     │
     ▼
CD Workflow triggers
     │
     ├──▶ Deploy to Staging (automatic)
     │          │
     │          ▼ (integration/smoke tests pass)
     │
     └──▶ Deploy to Production (requires manual approval)
                │
                ▼
          Update Kubernetes deployment
          Verify rollout health
          Notify Slack
```

---

## Deploy to Kubernetes (EKS)

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ap-south-1

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig \
            --name vault-staging-cluster \
            --region ap-south-1

      - name: Deploy
        run: |
          kubectl set image deployment/vault-api \
            vault-api=123456789.dkr.ecr.ap-south-1.amazonaws.com/vault-app:${{ github.sha }} \
            --namespace staging

      - name: Wait for rollout
        run: |
          kubectl rollout status deployment/vault-api \
            --namespace staging \
            --timeout=5m

      - name: Smoke test
        run: |
          sleep 10   # give pods time to be ready behind the service
          curl -f https://staging.vault.example.com/health || exit 1

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: deploy-staging
    environment: production       # ← requires approval in GitHub UI

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ap-south-1

      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name vault-prod-cluster --region ap-south-1

      - name: Deploy
        run: |
          kubectl set image deployment/vault-api \
            vault-api=123456789.dkr.ecr.ap-south-1.amazonaws.com/vault-app:${{ github.sha }} \
            --namespace production

      - name: Wait for rollout
        run: kubectl rollout status deployment/vault-api --namespace production --timeout=10m

      - name: Verify deployment
        run: |
          # Check if the new pods are healthy
          kubectl get pods -n production -l app=vault-api
          curl -f https://vault.example.com/health
```

---

## Deploy with Helm

Helm is the standard way to deploy to Kubernetes with configurable values per environment.

```yaml
- name: Install Helm
  uses: azure/setup-helm@v4
  with:
    version: '3.14.0'

- name: Deploy with Helm
  run: |
    helm upgrade --install vault-app ./helm/vault-app \
      --namespace production \
      --create-namespace \
      --set image.repository=123456789.dkr.ecr.ap-south-1.amazonaws.com/vault-app \
      --set image.tag=${{ github.sha }} \
      --set replicaCount=3 \
      --values ./helm/vault-app/values.production.yaml \
      --wait \
      --timeout 10m \
      --atomic              # if upgrade fails: auto rollback to previous release
```

Flags:
- `--install`: create if doesn't exist, upgrade if it does
- `--atomic`: automatically rolls back on failure (critical for prod)
- `--wait`: block until all pods are ready
- `--timeout 10m`: don't wait forever

### Helm with Separate Values Files per Environment

```yaml
- name: Deploy to staging
  run: |
    helm upgrade --install vault-app ./helm/vault-app \
      --values ./helm/values.yaml \
      --values ./helm/values.staging.yaml \    # staging overrides
      --set image.tag=${{ github.sha }}

- name: Deploy to production
  run: |
    helm upgrade --install vault-app ./helm/vault-app \
      --values ./helm/values.yaml \
      --values ./helm/values.production.yaml \ # production overrides
      --set image.tag=${{ github.sha }}
```

---

## Deploy to GKE

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: actions/checkout@v4

  - uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

  - uses: google-github-actions/setup-gcloud@v2

  - name: Get GKE credentials
    run: |
      gcloud container clusters get-credentials vault-cluster \
        --region asia-south1 \
        --project my-gcp-project

  - name: Deploy
    run: |
      kubectl set image deployment/vault-api \
        vault-api=asia-south1-docker.pkg.dev/my-project/vault-app:${{ github.sha }} \
        -n production
      kubectl rollout status deployment/vault-api -n production --timeout=5m
```

---

## Deploy to EC2 (Simple SSH Deploy)

For teams running apps directly on EC2 without Kubernetes:

```yaml
- name: Deploy to EC2
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: ${{ secrets.EC2_HOST }}
    username: ubuntu
    key: ${{ secrets.EC2_SSH_KEY }}
    script: |
      cd /app/vault-app
      docker pull 123456789.dkr.ecr.ap-south-1.amazonaws.com/vault-app:${{ github.sha }}
      docker stop vault-api || true
      docker rm vault-api || true
      docker run -d \
        --name vault-api \
        --env-file /etc/vault-app/.env \
        -p 3000:3000 \
        --restart unless-stopped \
        123456789.dkr.ecr.ap-south-1.amazonaws.com/vault-app:${{ github.sha }}
```

Better approach — use Docker Compose on EC2:

```yaml
- name: Deploy via Docker Compose
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: ${{ secrets.EC2_HOST }}
    username: ubuntu
    key: ${{ secrets.EC2_SSH_KEY }}
    script: |
      cd /app/vault-app
      # Update the image tag in .env
      echo "IMAGE_TAG=${{ github.sha }}" > .env.deploy
      # Pull and restart
      IMAGE_TAG=${{ github.sha }} docker compose pull
      IMAGE_TAG=${{ github.sha }} docker compose up -d
      # Wait for health
      sleep 15
      curl -f http://localhost:3000/health || exit 1
```

---

## Rollback Strategies

### Kubernetes Rollback on Failure

```yaml
- name: Deploy
  id: deploy
  run: |
    kubectl set image deployment/vault-api vault-api=...image:${{ github.sha }} -n production

- name: Wait for rollout
  id: rollout
  run: kubectl rollout status deployment/vault-api -n production --timeout=5m
  continue-on-error: true    # don't fail immediately — try to rollback

- name: Rollback on failure
  if: steps.rollout.outcome == 'failure'
  run: |
    echo "Rollout failed. Rolling back..."
    kubectl rollout undo deployment/vault-api -n production
    kubectl rollout status deployment/vault-api -n production --timeout=5m
    exit 1   # still fail the workflow so the team knows
```

### Helm Rollback on Failure

```yaml
- name: Deploy with Helm
  id: helm-deploy
  run: |
    helm upgrade vault-app ./helm/vault-app --atomic --timeout 10m
  continue-on-error: true

- name: Rollback on failure
  if: steps.helm-deploy.outcome == 'failure'
  run: |
    helm rollback vault-app
    exit 1
```

`--atomic` in Helm already does this automatically — including it is simpler.

---

## Deployment Notifications

### Slack Notification

```yaml
- name: Notify Slack — Success
  if: success()
  uses: slackapi/slack-github-action@v1.26.0
  with:
    payload: |
      {
        "text": "✅ Deployed vault-app:${{ github.sha }} to production",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*✅ Production Deploy Successful*\nCommit: `${{ github.sha }}`\nBy: ${{ github.actor }}\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Run>"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

- name: Notify Slack — Failure
  if: failure()
  uses: slackapi/slack-github-action@v1.26.0
  with:
    payload: |
      {
        "text": "🚨 Production Deploy FAILED — vault-app:${{ github.sha }}"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## Deploying on Git Tags (Release-Based CD)

```yaml
on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'   # v1.0.0, v2.3.1

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Extract version from tag
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_ENV
        # refs/tags/v1.2.3 → 1.2.3

      - name: Build and push Docker image
        run: |
          docker build -t vault-app:${{ env.VERSION }} .
          docker push ghcr.io/sanketika/vault-app:${{ env.VERSION }}
          docker push ghcr.io/sanketika/vault-app:latest

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true   # auto-generates from PRs and commits
          files: |
            dist/vault-app-linux-amd64
            dist/vault-app-darwin-arm64
```

---

## Real-World Scenario: Full CI/CD Pipeline for Vault App

Complete file combining CI and CD:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
  # On main push (deploy): don't cancel in progress — let it finish
  # On PRs: cancel previous run and start fresh

permissions:
  id-token: write
  contents: read
  packages: write

env:
  REGISTRY: ghcr.io
  IMAGE: ghcr.io/${{ github.repository }}

jobs:

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        ports: [5432:5432]
        options: --health-cmd pg_isready --health-interval 10s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: npm
      - run: npm ci
      - run: npm test
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/postgres

  build-push:
    needs: test
    if: github.event_name == 'push'     # only on merge, not on PRs
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ github.sha }}
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ env.IMAGE }}:${{ github.sha }},${{ env.IMAGE }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy-staging:
    needs: build-push
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_STAGING_ROLE }}
          aws-region: ap-south-1
      - run: aws eks update-kubeconfig --name vault-staging --region ap-south-1
      - run: |
          kubectl set image deployment/vault-api vault-api=${{ env.IMAGE }}:${{ github.sha }} -n staging
          kubectl rollout status deployment/vault-api -n staging --timeout=5m

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production             # manual approval required
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_PROD_ROLE }}
          aws-region: ap-south-1
      - run: aws eks update-kubeconfig --name vault-prod --region ap-south-1
      - run: |
          kubectl set image deployment/vault-api vault-api=${{ env.IMAGE }}:${{ github.sha }} -n production
          kubectl rollout status deployment/vault-api -n production --timeout=10m
```

---

## Common Misunderstanding: "Passing CI means safe to deploy"

**The misunderstanding:** "CI passed, so the deploy is safe."

**The reality:** CI tests catch code-level issues. Deployment failures are often:
- **Infrastructure**: the cluster is at capacity, the pull of the new image fails, the ConfigMap key is missing
- **Configuration drift**: staging and production have different secrets/env vars — works in staging, breaks in production
- **Race conditions during rollout**: new pods start before old ones stop → brief period of mixed versions hitting the database
- **Database migration conflicts**: old pods use old schema, new pods use new schema, running simultaneously during rollout

Defense:
1. Always `kubectl rollout status --timeout=Xm` — catch failures during rollout, not after
2. Use `--atomic` in Helm — auto-rollback if rollout fails
3. Have smoke tests run AFTER deploy, not before
4. Set `PodDisruptionBudget` to ensure old pods don't all die at once

→ Continue to: `06-advanced-patterns.md`
