# Helm — Part 04: Repositories, OCI Registries, and Managing Dependencies

**20-minute read. Find, add, inspect, and manage charts from public repos and OCI registries. Manage chart dependencies correctly.**

---

## Helm Repositories — The Traditional Way

A Helm repository is an HTTP server hosting an `index.yaml` (catalog) and chart `.tgz` packages.

### helm repo — Repository Management

```bash
# Add a repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add cert-manager https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm

# List all configured repos
helm repo list
# NAME               URL
# bitnami            https://charts.bitnami.com/bitnami
# ingress-nginx      https://kubernetes.github.io/ingress-nginx
# cert-manager       https://charts.jetstack.io

# Update the index (fetch latest chart listings)
helm repo update                  # update all repos
helm repo update bitnami          # update one repo

# Remove a repo
helm repo remove bitnami

# Show repo index contents (for debugging)
helm repo index ./my-chart-dir/   # generate index.yaml for a local directory
```

### Searching for Charts

```bash
# Search across all configured repos
helm search repo postgresql

# NAME                            CHART VERSION   APP VERSION    DESCRIPTION
# bitnami/postgresql              13.4.4          16.2.0         PostgreSQL chart
# bitnami/postgresql-ha           12.3.1          16.2.0         PostgreSQL HA using Repmgr

# Search for specific version pattern
helm search repo postgresql --version "13.*"

# Show all available versions of a chart
helm search repo bitnami/postgresql --versions

# Search Artifact Hub (public index of all public Helm charts)
helm search hub postgresql
helm search hub nginx --max-col-width 80
```

### Inspecting a Chart Before Installing

```bash
# Show Chart.yaml info
helm show chart bitnami/postgresql

# Show default values.yaml
helm show values bitnami/postgresql

# Show all info (chart + values + readme)
helm show all bitnami/postgresql

# Show specific version
helm show values bitnami/postgresql --version 13.4.4

# Best practice: redirect to a file for easier reading
helm show values bitnami/postgresql > postgresql-default-values.yaml
# Then review and copy the relevant sections to your override file
```

### Pulling a Chart Locally

```bash
# Download the chart .tgz without installing
helm pull bitnami/postgresql

# Pull and extract (so you can inspect files)
helm pull bitnami/postgresql --untar
ls postgresql/
# Chart.yaml  values.yaml  templates/  charts/  README.md

# Pull specific version
helm pull bitnami/postgresql --version 13.4.4 --untar

# Pull to specific directory
helm pull bitnami/postgresql --destination ./charts/
```

---

## OCI Registries — The Modern Way

OCI (Open Container Initiative) allows storing Helm charts in any container registry (ECR, GHCR, GAR, ACR, Docker Hub). This is the preferred approach for private charts because it reuses your existing registry infrastructure.

### Pushing and Pulling from OCI

```bash
# Login to GHCR
echo $GITHUB_TOKEN | helm registry login ghcr.io \
  --username your-username \
  --password-stdin

# Login to AWS ECR
aws ecr get-login-password --region ap-south-1 \
  | helm registry login \
  --username AWS \
  --password-stdin 123456789.dkr.ecr.ap-south-1.amazonaws.com

# Login to GCP Artifact Registry
gcloud auth print-access-token \
  | helm registry login asia-south1-docker.pkg.dev \
  --username oauth2accesstoken \
  --password-stdin

# Push a chart to OCI registry
helm package ./vault-app/             # creates vault-app-1.4.2.tgz
helm push vault-app-1.4.2.tgz oci://ghcr.io/sanketika/charts/

# Pull from OCI registry
helm pull oci://ghcr.io/sanketika/charts/vault-app --version 1.4.2

# Install directly from OCI
helm install vault-app oci://ghcr.io/sanketika/charts/vault-app \
  --version 1.4.2 \
  --values values.production.yaml

# Upgrade from OCI
helm upgrade vault-app oci://ghcr.io/sanketika/charts/vault-app \
  --version 1.5.0 \
  --values values.production.yaml \
  --atomic

# Inspect OCI chart without installing
helm show values oci://ghcr.io/sanketika/charts/vault-app --version 1.4.2
```

OCI charts don't need `helm repo add` — you reference them with `oci://` prefix directly.

---

## Chart Dependencies — Using Sub-Charts

When your app needs PostgreSQL, Redis, etc., you declare them as dependencies in `Chart.yaml` rather than running them as separate Helm releases.

### Declaring Dependencies

```yaml
# Chart.yaml
dependencies:
  - name: postgresql
    version: "13.4.x"                  # semver constraint: >= 13.4.0, < 13.5.0
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled      # only install if values.postgresql.enabled = true
    alias: postgres                    # use "postgres" as the key in values.yaml

  - name: redis
    version: "18.x.x"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: redis.enabled

  - name: vault-common
    version: "0.1.x"
    repository: "oci://ghcr.io/sanketika/charts"
    tags:
      - vault-infra
```

### Managing Dependencies

```bash
# Download all dependencies (into charts/ directory)
helm dependency update ./vault-app/
# Creates charts/postgresql-13.4.4.tgz, charts/redis-18.2.1.tgz
# Also creates Chart.lock (exact resolved versions)

# List current dependency state
helm dependency list ./vault-app/
# NAME         VERSION   REPOSITORY                            STATUS
# postgresql   13.4.x    https://charts.bitnami.com/bitnami   ok
# redis        18.x.x    oci://registry-1.docker.io/bitnami   missing   ← need to run dep update

# Build dependencies (same as update but uses Chart.lock if it exists)
helm dependency build ./vault-app/
# Use build in CI (ensures exact locked versions, fails if Chart.lock is out of date)
# Use update when you want to update to latest matching version
```

`Chart.lock` is like `package-lock.json` — commit it to git so CI builds use exact versions.

### Configuring Sub-Chart Values

Sub-chart values are nested under the dependency name (or alias) in the parent's values.yaml:

```yaml
# values.yaml
# Top-level key matches the dependency alias ("postgres" from Chart.yaml)
postgres:
  enabled: true
  auth:
    username: vaultadmin
    database: vault
    existingSecret: vault-postgres-creds
  primary:
    persistence:
      enabled: true
      size: 20Gi
      storageClass: gp3
  resources:
    requests:
      cpu: 250m
      memory: 256Mi

redis:
  enabled: true
  auth:
    enabled: false
  master:
    persistence:
      size: 5Gi
```

### Connecting Your App to the Sub-Chart Service

Sub-chart services are accessible via their Helm-generated service name. The pattern is `<release-name>-<sub-chart-name>`:

```yaml
# templates/deployment.yaml — your app's environment variables
env:
  - name: DATABASE_URL
    value: "postgresql://vaultadmin:$(DB_PASSWORD)@{{ .Release.Name }}-postgres:5432/vault"
    # Release: vault-app
    # Sub-chart alias: postgres
    # Result: vault-app-postgres:5432
```

Or more robustly, in values.yaml:
```yaml
database:
  host: ""    # empty = auto-derive from sub-chart; set explicitly for external DB
```

```yaml
# templates/deployment.yaml
{{- $dbHost := .Values.database.host | default (printf "%s-postgres" .Release.Name) }}
- name: DATABASE_HOST
  value: {{ $dbHost }}
```

---

## Essential Charts Reference

| Chart | Use |
|-------|-----|
| `bitnami/postgresql` | PostgreSQL database |
| `bitnami/redis` | Redis cache |
| `ingress-nginx/ingress-nginx` | Nginx Ingress Controller |
| `cert-manager/cert-manager` | Automatic TLS certificate management |
| `prometheus-community/kube-prometheus-stack` | Prometheus + Grafana + AlertManager (whole stack) |
| `grafana/loki-stack` | Loki + Promtail log aggregation |
| `grafana/alloy` | Grafana Alloy collector |
| `argo/argo-cd` | ArgoCD GitOps operator |
| `bitnami/external-secrets` | Sync secrets from AWS Secrets Manager / Vault |
| `bitnami/sealed-secrets` | Encrypt secrets for git storage |

---

## Installing Production-Grade Third-Party Charts

### cert-manager Example

```bash
helm repo add cert-manager https://charts.jetstack.io
helm repo update

# cert-manager requires CRDs — install them separately
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.crds.yaml

# Install cert-manager
helm install cert-manager cert-manager/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.0

# Verify
kubectl get pods -n cert-manager
```

### ingress-nginx Example

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Show available configuration options
helm show values ingress-nginx/ingress-nginx > ingress-values.yaml

# Install with basic production settings
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.resources.requests.cpu=100m \
  --set controller.resources.requests.memory=90Mi \
  --wait
```

---

## Real-World Scenario: Pinning Chart Versions in Production

Never install charts without pinning the version. `latest` in Helm repos can break your infrastructure silently.

```bash
# WRONG — installs whatever is latest today, might break tomorrow
helm install postgres bitnami/postgresql

# CORRECT — always pin
helm install postgres bitnami/postgresql --version 13.4.4

# To find the current latest version:
helm search repo bitnami/postgresql --versions | head -5

# To audit what version is installed:
helm list -n production -o json | jq '.[].chart'
# "postgresql-13.4.4"

# In CI/CD, store the version in a config file:
# helm-versions.yaml (in your repo)
# postgresql: 13.4.4
# ingress-nginx: 4.9.1
# cert-manager: v1.14.0
```

Then in your deployment script:
```bash
POSTGRESQL_VERSION=$(yq .postgresql helm-versions.yaml)
helm upgrade --install postgres bitnami/postgresql \
  --version $POSTGRESQL_VERSION \
  --values postgresql-values.yaml
```

---

## Common Misunderstanding: "helm repo update is automatic"

**The misunderstanding:** "After `helm repo add`, the chart catalog stays current."

**The reality:** `helm repo add` only adds the repo configuration. The chart index is fetched once and cached locally. It does NOT auto-update.

If you added `bitnami` last month and a new chart version was released yesterday, `helm search repo bitnami/postgresql --versions` will NOT show it until you run:

```bash
helm repo update
```

In CI/CD pipelines, always run `helm repo update` before `helm install` or `helm upgrade` to ensure you're seeing and able to use the latest available versions:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update bitnami     # always before using
helm install postgres bitnami/postgresql --version 13.4.4
```

→ Continue to: `05-building-charts.md`
