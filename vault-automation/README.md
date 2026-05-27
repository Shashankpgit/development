# Vault Automation

All Kubernetes and Helm automation for the Personal Vault application.

Everything that was previously done via raw `kubectl` or `helm` commands lives here as code — reviewed, committed, version-controlled.

---

## Directory structure

```
vault-automation/
├── helm/
│   ├── vault-api/          ← Helm chart for the FastAPI backend (written by us)
│   ├── vault-frontend/     ← Helm chart for the React frontend + nginx (written by us)
│   ├── vault/              ← Umbrella chart — ties all services together
│   └── values/             ← values files for community charts
│       ├── postgresql.yaml ← bitnami/postgresql configuration
│       ├── keycloak.yaml   ← bitnami/keycloak configuration
│       └── kong.yaml       ← kong/kong configuration
└── k8s/
    └── namespace.yaml      ← vault namespace
```

## What lives here vs in the app repo

| Thing | Where |
|---|---|
| FastAPI backend code | `vault/backend/` |
| React frontend code | `vault/frontend/` |
| Docker images | Built by GitHub Actions, pushed to GHCR |
| K8s manifests + Helm charts | HERE (`vault-automation/`) |
| CI/CD workflows | `.github/workflows/` |

## Deployment flow

```
Code push → GitHub Actions builds image → pushes to GHCR
                                               ↓
                              helm upgrade --install vault helm/vault/
                                               ↓
                                    GKE pulls image from GHCR
```
