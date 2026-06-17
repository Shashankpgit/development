# Helm — Complete Guide for DevOps Engineers

**7 files. ~20 minutes each. Charts to production deployments.**

---

## Reading Order

| File | Topic | What you'll be able to do |
|------|--------|--------------------------|
| [00-mental-model.md](00-mental-model.md) | Charts, releases, repos, rendering model | Understand why Helm exists and how it works |
| [01-cli-basics.md](01-cli-basics.md) | install, upgrade, rollback, history, get, diff | Manage any Helm release in production |
| [02-chart-structure.md](02-chart-structure.md) | Chart.yaml, values.yaml, templates, hooks, tests | Read and modify any third-party chart |
| [03-values-and-templating.md](03-values-and-templating.md) | Go templates, conditionals, loops, functions | Write chart templates that work for any environment |
| [04-repositories-and-oci.md](04-repositories-and-oci.md) | helm repo, OCI registries, dependencies | Find, install, and version-pin charts; manage sub-charts |
| [05-building-charts.md](05-building-charts.md) | helm create, lint, test, package, publish | Build and publish production-ready charts |
| [06-real-world-patterns.md](06-real-world-patterns.md) | Umbrella charts, Helmfile, ArgoCD, GitOps | Manage a full infrastructure with Helm at scale |

---

## Quick Command Reference

### Daily Operations
```bash
# List all releases
helm list -A

# Install / upgrade (idempotent)
helm upgrade --install <name> <chart> -n <namespace> --create-namespace

# Safe production upgrade
helm upgrade <name> <chart> -n <namespace> --atomic --timeout 10m --values values.yaml

# Check current values
helm get values <name> -n <namespace>

# Preview before upgrading
helm diff upgrade <name> <chart> -n <namespace> --values values.yaml

# Rollback immediately
helm rollback <name> -n <namespace> --wait

# Rollback to specific revision
helm rollback <name> <revision> -n <namespace>

# View history
helm history <name> -n <namespace>

# Delete a release
helm uninstall <name> -n <namespace>
```

### Inspecting Charts
```bash
# See default values
helm show values bitnami/postgresql

# See chart info
helm show chart bitnami/postgresql

# Render templates locally
helm template <name> <chart> --values values.yaml

# Render one template only
helm template <name> <chart> --show-only templates/deployment.yaml

# Lint
helm lint ./my-chart/ --strict --values ci/values.yaml
```

### Repositories
```bash
# Add common repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add cert-manager https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update

# Search
helm search repo postgresql
helm search repo postgresql --versions   # all versions
```

### OCI Registries
```bash
# Login
echo $TOKEN | helm registry login ghcr.io --username user --password-stdin

# Push
helm package ./my-chart/
helm push my-chart-1.0.0.tgz oci://ghcr.io/owner/charts/

# Install from OCI
helm install my-app oci://ghcr.io/owner/charts/my-chart --version 1.0.0
```

### Dependencies
```bash
helm dependency update ./chart/    # download deps (updates Chart.lock)
helm dependency build ./chart/     # use Chart.lock exactly
helm dependency list ./chart/      # show dep status
```

---

## Template Quick Reference

```yaml
# Value reference
{{ .Values.image.tag }}

# With default fallback
{{ .Values.image.tag | default .Chart.AppVersion }}

# Required value (fail if empty)
{{ required "image.tag is required" .Values.image.tag }}

# Quote a string
{{ .Values.name | quote }}

# toYaml for nested objects (always use nindent for correct indentation)
{{ toYaml .Values.resources | nindent 12 }}

# Conditional block
{{- if .Values.ingress.enabled }}
# ... ingress yaml
{{- end }}

# Loop over map
{{- range $k, $v := .Values.env }}
- name: {{ $k }}
  value: {{ $v | quote }}
{{- end }}

# Call a helper function
{{ include "chart.fullname" . }}

# Call helper in labels position (multi-line)
labels:
  {{- include "chart.labels" . | nindent 4 }}

# Conditional with 'with' (skips block if value is empty)
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

---

## Essential Third-Party Charts

| Chart | Install Command |
|-------|----------------|
| PostgreSQL | `helm install pg bitnami/postgresql --version 13.4.4` |
| Redis | `helm install redis bitnami/redis --version 18.x.x` |
| Ingress Nginx | `helm install ingress-nginx ingress-nginx/ingress-nginx` |
| cert-manager | `helm install cert-manager cert-manager/cert-manager --version v1.14.0` |
| Prometheus Stack | `helm install kube-prom prometheus-community/kube-prometheus-stack` |
| Loki Stack | `helm install loki grafana/loki-stack` |
| ArgoCD | `helm install argocd argo/argo-cd` |

---

## Flags You'll Use Most

| Flag | When to use |
|------|------------|
| `--upgrade --install` | Idempotent — use in all CI/CD pipelines |
| `--atomic` | Auto-rollback on failure — always use for production |
| `--wait` | Block until pods ready — use with `--atomic` |
| `--timeout 10m` | How long to wait — adjust to your app startup time |
| `--dry-run --debug` | Preview what would deploy — always review before first install |
| `--values file.yaml` | Pass override values file |
| `--set key=val` | Single value override — for image tags, env-specific values |
| `--reuse-values` | Keep previous values — avoid in CI, use for quick manual fixes |
| `--create-namespace` | Create namespace if missing — safe for first deploy |
| `--history-max 20` | Keep more history — useful for active services |
