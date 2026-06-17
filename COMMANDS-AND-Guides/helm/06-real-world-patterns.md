# Helm — Part 06: Real-World Patterns

**20-minute read. Umbrella charts, Helmfile, CI/CD integration, ArgoCD, and the patterns teams actually use at scale.**

---

## Umbrella Charts — Deploy a Full Stack

An umbrella chart is a parent chart whose entire purpose is to group multiple sub-charts together. It contains no templates of its own — just dependencies.

### When to Use Umbrella Charts

You want to deploy vault-api + PostgreSQL + Redis + ingress-nginx together as one unit:

```
vault-stack/               ← umbrella chart (no templates)
├── Chart.yaml             ← lists vault-app, postgresql, redis as dependencies
├── values.yaml            ← all config in one place
└── charts/                ← populated after helm dep update
    ├── vault-app-1.4.2.tgz
    ├── postgresql-13.4.4.tgz
    └── redis-18.2.1.tgz
```

```yaml
# Chart.yaml — umbrella
apiVersion: v2
name: vault-stack
description: Complete Vault application stack
type: application
version: 1.0.0

dependencies:
  - name: vault-app
    version: "1.4.x"
    repository: "oci://ghcr.io/sanketika/charts"

  - name: postgresql
    version: "13.4.x"
    repository: "https://charts.bitnami.com/bitnami"
    alias: postgres

  - name: redis
    version: "18.x.x"
    repository: "https://charts.bitnami.com/bitnami"
```

```yaml
# values.yaml — umbrella (all sub-chart values nested under their names)
vault-app:
  replicaCount: 2
  image:
    tag: v1.2.3
  ingress:
    enabled: true
    hosts:
      - host: vault.example.com

postgres:
  enabled: true
  auth:
    username: vaultadmin
    database: vault
    existingSecret: vault-pg-creds

redis:
  auth:
    enabled: false
  master:
    persistence:
      size: 5Gi
```

```bash
# Download dependencies
helm dependency update ./vault-stack/

# Deploy the whole stack in one command
helm install vault vault-stack/ \
  --namespace production \
  --create-namespace

# This deploys vault-app, PostgreSQL, and Redis all at once
```

---

## Helmfile — Declarative Multi-Chart Management

Helmfile lets you declare ALL your Helm releases in a single YAML file and manage them with one command. Think of it as `docker-compose` for Helm charts.

```bash
# Install helmfile
curl -fsSL https://github.com/helmfile/helmfile/releases/download/v0.162.0/helmfile_0.162.0_linux_amd64.tar.gz | tar xz
sudo mv helmfile /usr/local/bin/

# Verify
helmfile version
```

### helmfile.yaml

```yaml
# helmfile.yaml
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami
  - name: ingress-nginx
    url: https://kubernetes.github.io/ingress-nginx
  - name: cert-manager
    url: https://charts.jetstack.io

# Environment-specific values
environments:
  staging:
    values:
      - environments/staging/values.yaml
  production:
    values:
      - environments/production/values.yaml

releases:
  # Ingress Controller
  - name: ingress-nginx
    namespace: ingress-nginx
    chart: ingress-nginx/ingress-nginx
    version: "4.9.1"
    values:
      - controller:
          replicaCount: 2

  # cert-manager
  - name: cert-manager
    namespace: cert-manager
    chart: cert-manager/cert-manager
    version: "v1.14.0"
    hooks:
      - events: ["presync"]
        command: kubectl
        args: ["apply", "-f", "https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.crds.yaml"]

  # Application
  - name: vault-app
    namespace: production
    chart: oci://ghcr.io/sanketika/charts/vault-app
    version: "1.4.2"
    values:
      - values/vault-app.yaml             # base values
      - values/vault-app.{{ .Environment.Name }}.yaml  # environment overlay
    set:
      - name: image.tag
        value: {{ requiredEnv "IMAGE_TAG" }}   # must be set as env var

  # PostgreSQL
  - name: postgres
    namespace: production
    chart: bitnami/postgresql
    version: "13.4.4"
    values:
      - values/postgres.yaml
      - values/postgres.{{ .Environment.Name }}.yaml
    needs:
      - production/cert-manager            # deploy after cert-manager
```

### Helmfile Commands

```bash
# Diff — show what would change across ALL releases
helmfile diff

# Sync — apply all releases (install if missing, upgrade if changed)
helmfile sync

# Sync with environment
helmfile --environment production sync

# Sync with image tag
IMAGE_TAG=v1.2.3 helmfile --environment production sync

# Only sync specific release
helmfile --selector name=vault-app sync

# Destroy ALL releases (careful!)
helmfile destroy

# List all releases and their status
helmfile list

# Template — render all charts to stdout
helmfile template

# Lint all charts
helmfile lint
```

### Helmfile for Environment Promotion

```
environments/
  staging/
    values.yaml      (replicaCount: 1, resources: small)
  production/
    values.yaml      (replicaCount: 3, resources: large)
values/
  vault-app.yaml         (shared: image.repository, service config)
  vault-app.staging.yaml (host: staging.vault.example.com)
  vault-app.production.yaml (host: vault.example.com, tls: enabled)
```

---

## Helm in CI/CD — Production Patterns

### Pattern 1: Direct Deploy from CI (Simple)

```yaml
# .github/workflows/deploy.yml
- name: Deploy with Helm
  run: |
    helm upgrade --install vault-app \
      oci://ghcr.io/sanketika/charts/vault-app \
      --version ${{ env.CHART_VERSION }} \
      --namespace production \
      --create-namespace \
      --values values/vault-app.yaml \
      --values values/vault-app.production.yaml \
      --set image.tag=${{ github.sha }} \
      --atomic \
      --timeout 10m
```

### Pattern 2: GitOps — Update Values in Config Repo

The CI pipeline doesn't deploy directly. It updates a value in a GitOps config repo, and ArgoCD deploys from there.

```yaml
# .github/workflows/deploy.yml
- name: Update image tag in GitOps repo
  env:
    GH_TOKEN: ${{ secrets.GITOPS_PAT }}
  run: |
    git clone https://x-access-token:${GH_TOKEN}@github.com/sanketika/vault-configs.git
    cd vault-configs

    # Update vault-app image tag using yq
    yq e '.vault-app.image.tag = "${{ github.sha }}"' \
      -i releases/production/values.yaml

    git config user.email "ci@sanketika.in"
    git config user.name "GitHub Actions"
    git add releases/production/values.yaml
    git commit -m "chore(vault-app): bump image to ${{ github.sha }}"
    git push
```

ArgoCD detects the git change and syncs the cluster.

---

## ArgoCD with Helm — The Standard GitOps Pattern

ArgoCD is the most common way to use Helm in production. It watches a git repo and keeps the cluster in sync.

### ArgoCD Application for Helm

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vault-app
  namespace: argocd
spec:
  project: default

  source:
    repoURL: oci://ghcr.io/sanketika/charts     # chart source
    chart: vault-app                             # chart name
    targetRevision: 1.4.2                        # chart version

    helm:
      valueFiles:
        - values/vault-app.yaml
        - values/vault-app.production.yaml
      parameters:
        - name: image.tag
          value: a3f7d2c4e5b6f7a8b9c0d1e2f3a4b5c6
          # image.tag set here gets overridden by your CI pushing to git

  destination:
    server: https://kubernetes.default.svc
    namespace: production

  syncPolicy:
    automated:
      prune: true          # delete resources removed from chart
      selfHeal: true       # revert manual kubectl changes
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

```bash
# Apply the ArgoCD Application definition
kubectl apply -f argocd-app.yaml -n argocd

# Check sync status
kubectl get application vault-app -n argocd

# Force sync now
argocd app sync vault-app

# Check app health
argocd app get vault-app
```

---

## Helm Secrets — Encrypting Sensitive Values

`helm-secrets` is a plugin that encrypts values files using SOPS (AWS KMS, GCP KMS, or PGP).

```bash
# Install plugin
helm plugin install https://github.com/jkroepke/helm-secrets

# Encrypt a values file (requires SOPS configured with your KMS key)
helm secrets encrypt values.secrets.yaml > values.secrets.enc.yaml

# Deploy using encrypted secrets
helm secrets upgrade vault-app ./vault-app/ \
  -f values.yaml \
  -f values.secrets.enc.yaml \    # auto-decrypted at deploy time
  --set image.tag=v1.2.3
```

The encrypted file is safe to commit to git. Only the CI system (with KMS access) can decrypt it.

---

## Debugging Helm Releases

```bash
# See the exact manifests Helm applied
helm get manifest vault-app -n production

# Check what values are actually in use
helm get values vault-app -n production --all

# See Helm's release history including descriptions
helm history vault-app -n production

# Check K8s events after a failed deploy
kubectl get events -n production --sort-by=.lastTimestamp | tail -20

# Describe a failing pod
kubectl describe pod vault-app-7d4b9c-xyz -n production

# Check if Helm release Secrets exist (where history is stored)
kubectl get secrets -n production | grep helm.sh

# Decode a specific revision's manifest
kubectl get secret sh.helm.release.v1.vault-app.v5 \
  -n production \
  -o jsonpath='{.data.release}' | base64 -d | base64 -d | gzip -d | jq .

# Full release diff: what changed between revision 4 and 5
helm diff revision vault-app 4 5 -n production
```

---

## Real-World Scenario: Rolling Back a Bad Production Release

```bash
# Scenario: v2.0.0 deployed, users reporting 500 errors

# 1. Immediately check what's wrong
kubectl get pods -n production           # any CrashLoopBackOff?
kubectl logs -n production deployment/vault-app --tail=50  # app errors?

# 2. How long until SLA breach? Check when the deploy happened
helm history vault-app -n production
# REVISION  UPDATED       STATUS    CHART           DESCRIPTION
# 7         10:45 AM      deployed  vault-app-2.0.0  Upgrade complete  ← current
# 6         09:00 AM      superseded vault-app-1.9.2

# 3. Rollback NOW (creates revision 8)
helm rollback vault-app 6 -n production --wait --timeout 5m

# 4. Verify rollback completed
helm status vault-app -n production
kubectl get pods -n production

# 5. Check users are no longer seeing errors
curl -s https://vault.example.com/health

# 6. Confirm the history shows rollback
helm history vault-app -n production
# REVISION  STATUS       DESCRIPTION
# 6         superseded   Upgrade complete
# 7         superseded   Upgrade complete
# 8         deployed     Rollback to 6    ← we're here now
```

---

## Common Misunderstanding: "Helm --atomic guarantees zero downtime"

**The misunderstanding:** "I use `--atomic`, so my deployments never cause downtime."

**The reality:** `--atomic` guarantees that **if the upgrade fails**, it rolls back. It does NOT guarantee zero downtime during the upgrade itself.

During a rolling upgrade, Kubernetes terminates old pods while starting new ones. Downtime occurs when:
- New pods start but `readinessProbe` fails → they're not ready → traffic hits fewer pods
- Old pods are terminated before new pods are ready (missing `PodDisruptionBudget`)
- The new version has a bug that causes crashes before `--atomic` timeout triggers rollback

For true zero downtime:
```yaml
# In your chart's deployment.yaml:
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0     # never kill old pods until new ones are ready
      maxSurge: 1           # allow one extra pod during upgrade

# And in a separate PodDisruptionBudget template:
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: vault-app-pdb
spec:
  minAvailable: 1           # always keep at least 1 pod running
  selector:
    matchLabels:
      app.kubernetes.io/name: vault-app
```

`--atomic` + `maxUnavailable: 0` + `readinessProbe` + `PodDisruptionBudget` together give you near-zero downtime deployments.

→ Continue to: `README.md`
