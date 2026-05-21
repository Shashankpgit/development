# Phase 11 — Step 1: Helm Charts

## What this step covers
Package the Kubernetes manifests into a Helm chart. Introduce templating so the same chart deploys to dev, staging, and production with different values.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/018-helm-plan.md` first
- [ ] Confirm all Phase 10 K8s manifests work correctly
- [ ] Explain what problem Helm solves before installing it

---

## Why this step exists

The raw K8s manifests from Phase 10 have a problem: `dev` and `production` need different values (different image tags, different replica counts, different resource limits, different domains). Currently, changing environments means manually editing YAML files — error-prone and not version-controlled cleanly.

Helm solves this with templating:
- One chart defines the structure
- `values.yaml` holds the defaults
- `values.prod.yaml` overrides for production
- `helm install` renders the templates and applies them

This is the de facto standard for deploying applications on Kubernetes.

---

## What to implement

### Initialize Helm chart
```bash
helm create vault
```
Then clean up the generated boilerplate and replace with our actual manifests.

### Chart structure
```
helm/vault/
├── Chart.yaml           ← chart name, version, description
├── values.yaml          ← default values (dev)
├── values.prod.yaml     ← production overrides
└── templates/
    ├── deployment.yaml  ← templated Deployment
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap.yaml
    ├── secret.yaml
    └── _helpers.tpl     ← shared template helpers
```

### Template example
```yaml
# templates/deployment.yaml
replicas: {{ .Values.api.replicas }}
image: {{ .Values.api.image }}:{{ .Values.api.tag }}
```

### `values.yaml` (dev defaults)
```yaml
api:
  replicas: 1
  image: vault-api
  tag: latest
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
```

### `values.prod.yaml` (production overrides)
```yaml
api:
  replicas: 3
  tag: "1.2.0"
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
```

---

## Concepts to teach during this step

- **What Helm is**: A package manager for Kubernetes. Like `apt` for Ubuntu or `pip` for Python, but for K8s applications.

- **Chart**: A Helm package. Contains all the K8s manifest templates for an application.

- **Release**: A deployed instance of a chart. `helm install my-vault ./vault` creates a release named `my-vault`.

- **Values**: Variables that templates use. Allows one chart to deploy to many environments with different configs.

- **Templating with Go templates**: `{{ .Values.api.replicas }}` is how Helm injects values into YAML. Looks like Jinja2 if you've seen that.

- **`helm upgrade --install`**: The idempotent command — installs if not present, upgrades if it is. This is what CI/CD pipelines use.

- **`helm template`**: Renders the templates without installing — useful for debugging. "Show me what K8s YAML this would generate."

- **`_helpers.tpl`**: Shared template logic (like app name, labels) extracted to avoid repetition. The underscore means Helm treats it as a helper, not a K8s manifest.

- **Chart versioning**: `Chart.yaml` has a `version` (chart version) and an `appVersion` (application version). Separate concerns.

---

## Commands to learn

```bash
helm install vault ./helm/vault
helm upgrade vault ./helm/vault
helm rollback vault 1
helm list
helm uninstall vault
helm template ./helm/vault --values values.prod.yaml  # dry run
```

---

## What NOT to do in this step

- Do NOT publish to a Helm repository yet
- Do NOT add Helm tests yet
- Do NOT use Helmfile yet (that's a further abstraction)

---

## File changes

| File | Action |
|---|---|
| `helm/vault/Chart.yaml` | Create |
| `helm/vault/values.yaml` | Create |
| `helm/vault/values.prod.yaml` | Create |
| `helm/vault/templates/*.yaml` | Create — converted from `k8s/*.yaml` |
| `k8s/` directory | Keep — raw manifests remain as reference |

---

## Success criteria

```bash
helm install vault ./helm/vault
kubectl get pods -n vault  # same result as Phase 10 kubectl apply
helm upgrade vault ./helm/vault --set api.replicas=3
kubectl get pods -n vault  # 3 API pods
helm template ./helm/vault --values helm/vault/values.prod.yaml  # shows prod-ready YAML
```
