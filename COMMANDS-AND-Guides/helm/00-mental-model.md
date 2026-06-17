# Helm — Part 00: Mental Model

**20-minute read. Understand what Helm is, why it exists, and how its three core concepts fit together before touching any commands.**

---

## Why Helm Exists

Without Helm, deploying an app to Kubernetes means maintaining many separate YAML files:

```
vault-app/
  deployment.yaml        (100 lines)
  service.yaml           (20 lines)
  ingress.yaml           (30 lines)
  configmap.yaml         (15 lines)
  secret.yaml            (10 lines)
  hpa.yaml               (20 lines)
  serviceaccount.yaml    (10 lines)
  networkpolicy.yaml     (30 lines)
```

Problems this creates:
1. **No parameterization** — staging and production differ only in replica count and image tag, but you maintain two full copies of every file
2. **No versioning** — `kubectl apply` has no concept of "this is version 3 of the app" — you can't roll back
3. **No dependency management** — your app depends on PostgreSQL and Redis, but there's no standard way to declare and install them
4. **Hard to share** — there's no standard way to distribute a set of Kubernetes manifests

Helm solves all four.

---

## The Three Core Concepts

### 1. Chart
A **chart** is a package — a directory (or `.tgz` archive) containing all the Kubernetes manifest templates for one application. It's parameterized: instead of hardcoding `image: vault-app:latest`, it uses `image: {{ .Values.image.tag }}`.

Think of a chart like a Docker image — a reusable, shareable, versioned artifact.

### 2. Release
A **release** is one running instance of a chart in a cluster. When you run `helm install my-vault-prod vault-app-chart`, you create a release named `my-vault-prod`. Running `helm install my-vault-staging vault-app-chart` creates a second, independent release.

Two releases of the same chart can coexist in the same cluster with different values. Each release is tracked independently — you can upgrade, rollback, or delete them separately.

### 3. Repository
A **repository** is a server that hosts chart packages (`.tgz` files) with an index. The most famous is `https://charts.helm.sh/stable`. You add repos with `helm repo add`, then install charts from them with `helm install`.

Modern Helm also supports **OCI registries** — you can push charts to any Docker registry (ECR, GHCR, GAR).

---

## The Big Picture

```
Chart Repository / OCI Registry
  (bitnami/postgresql, your-org/vault-app)
         │
         │ helm install / helm upgrade
         ▼
    Helm (CLI on your laptop or CI)
         │
         │ Renders templates with values
         │ Applies to cluster via Kubernetes API
         ▼
    Kubernetes Cluster
         │
         ├── Namespace: staging
         │     └── Release: vault-app-staging (v1)
         │           ├── Deployment: vault-api
         │           ├── Service: vault-api
         │           └── Ingress: vault-api
         │
         └── Namespace: production
               └── Release: vault-app-production (v3)
                     ├── Deployment: vault-api (3 replicas)
                     ├── Service: vault-api
                     └── Ingress: vault-api
```

Helm stores release history as Kubernetes Secrets in the same namespace. No separate Helm server needed (Helm v2 had Tiller; v3 removed it — client-only).

---

## Chart Directory Structure

```
vault-app/                     ← chart root (= chart name)
├── Chart.yaml                 ← metadata: name, version, appVersion, dependencies
├── values.yaml                ← default values for all templates
├── values.staging.yaml        ← (optional) override file for staging
├── values.production.yaml     ← (optional) override file for production
├── templates/                 ← Kubernetes manifest templates
│   ├── _helpers.tpl           ← reusable template functions (NOT rendered directly)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── hpa.yaml
│   ├── serviceaccount.yaml
│   └── NOTES.txt              ← printed to user after helm install
├── charts/                    ← dependency charts live here after `helm dep update`
└── .helmignore                ← files to exclude when packaging (like .gitignore)
```

---

## How Helm Renders a Template

When you run `helm install`, Helm:
1. Reads `values.yaml` (defaults) and merges your overrides (`-f values.production.yaml`, `--set image.tag=v1.2`)
2. Renders each `.yaml` in `templates/` using Go's template engine
3. Validates the rendered YAML
4. Sends it to the Kubernetes API server

```
templates/deployment.yaml (template):

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-api
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
        - image: {{ .Values.image.repository }}:{{ .Values.image.tag }}

─────────────────────────────────────────────────────────────────

values.yaml (defaults):

replicaCount: 1
image:
  repository: ghcr.io/sanketika/vault-app
  tag: latest

─────────────────────────────────────────────────────────────────

Rendered output (what Kubernetes receives):

apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-app-production-api
spec:
  replicas: 3
  template:
    spec:
      containers:
        - image: ghcr.io/sanketika/vault-app:v1.2.3
```

---

## Built-in Objects in Templates

Helm provides several built-in objects you can use in templates:

```yaml
# .Release — information about the release
{{ .Release.Name }}         # vault-app-production
{{ .Release.Namespace }}    # production
{{ .Release.IsInstall }}    # true on first install, false on upgrade
{{ .Release.IsUpgrade }}    # true on upgrade
{{ .Release.Revision }}     # 1, 2, 3 (increments on each upgrade)

# .Chart — Chart.yaml contents
{{ .Chart.Name }}           # vault-app
{{ .Chart.Version }}        # 1.4.2
{{ .Chart.AppVersion }}     # 2.1.0

# .Values — values.yaml merged with overrides
{{ .Values.image.tag }}
{{ .Values.replicaCount }}

# .Files — access non-template files in the chart
{{ .Files.Get "config/app.conf" }}

# .Capabilities — what the cluster supports
{{ .Capabilities.KubeVersion.Major }}
```

---

## Chart.yaml — The Manifest File

```yaml
# Chart.yaml
apiVersion: v2              # always v2 for Helm 3
name: vault-app
description: Vault password manager application
type: application           # application (default) or library

version: 1.4.2              # CHART version (semver) — increment when chart changes
appVersion: "2.1.0"         # APP version — the version of your application code

keywords:
  - vault
  - passwords

dependencies:               # sub-charts this chart depends on
  - name: postgresql
    version: "13.4.x"       # semver constraint
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled   # only install if this value is true

  - name: redis
    version: "18.x.x"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: redis.enabled
```

`version` vs `appVersion`:
- `version` — the version of the **chart itself** (your YAML templates, defaults, structure)
- `appVersion` — the version of the **application** the chart deploys. Informational only — doesn't affect anything functionally.

---

## Helm v2 vs Helm v3

You'll encounter older docs mentioning Tiller. Ignore those — Helm v3 (current) removed it:

| Feature | Helm v2 | Helm v3 |
|---------|---------|---------|
| Server component | Tiller (ran in cluster) | None — client only |
| Security | Tiller had cluster-admin | Uses your kubeconfig permissions |
| Release storage | Tiller's ConfigMaps | Kubernetes Secrets in release namespace |
| Namespace isolation | None (global) | Per-namespace releases |

If a tutorial says "install Tiller" — it's outdated. Use Helm v3.

---

## Real-World Scenario: Why "just kubectl apply" breaks down

**The problem:** Your app is deployed with `kubectl apply -f manifests/`. A junior team member runs:

```bash
kubectl delete configmap vault-config -n production
# Oops — thought it was staging
```

With raw kubectl:
- No audit trail of what was deployed when
- No rollback: you have to manually recreate the ConfigMap from git history
- No way to know what version of the manifests is currently running in the cluster

With Helm:
```bash
# The delete still happened, but:
helm history vault-app -n production
# REVISION  STATUS     DESCRIPTION
# 1         superseded Install complete
# 2         superseded Upgrade complete
# 3         deployed   Upgrade complete

# Restore previous complete state (all resources):
helm rollback vault-app 2 -n production
# Rolled back vault-app to revision 2
# All resources (ConfigMap, Deployment, Service) restored from revision 2's snapshot
```

Helm's rollback re-applies ALL the resources from the target revision — not just individual files.

---

## Common Misunderstanding: "Helm manages Kubernetes resources like Terraform manages infrastructure"

**The misunderstanding:** "If I delete a Kubernetes resource manually, Helm will detect the drift and recreate it."

**The reality:** Helm does NOT continuously reconcile state. It's imperative (like kubectl), not declarative (like Terraform or ArgoCD).

Helm only acts when you run a command:
- `helm install` → creates resources
- `helm upgrade` → diffs and applies changes
- `helm rollback` → restores a previous revision
- `helm uninstall` → deletes resources

If you manually `kubectl delete` a resource that Helm created, Helm doesn't know and won't recreate it — until you run `helm upgrade` again, which re-applies all resources.

For continuous reconciliation (drift detection + auto-repair), use **ArgoCD** or **Flux** on top of Helm. They watch for drift and re-apply Helm releases when they drift.

→ Continue to: `01-cli-basics.md`
