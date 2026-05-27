# Vault Automation

All Kubernetes and Helm automation for the Personal Vault application.

---

## Directory structure

```
vault-automation/
│
├── charts/                        Custom Helm charts — written by us
│   ├── vault-api/                 FastAPI backend chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   └── vault-frontend/            React + nginx frontend chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│
├── overrides/                     Value overrides for community charts
│   ├── cert-manager.yaml          overrides for cert-manager/cert-manager
│   ├── ingress-nginx.yaml         overrides for ingress-nginx/ingress-nginx
│   ├── postgresql.yaml            overrides for bitnami/postgresql
│   ├── keycloak.yaml              overrides for bitnami/keycloak
│   └── kong.yaml                  overrides for kong/kong
│
├── global-values.yaml             Image tags, domain, replica counts (committed)
├── global-cloud-values.yaml       GKE-specific: storage class, resources (committed)
├── global-secrets.example.yaml    Template for secrets — copy and fill in (committed)
└── global-secrets.yaml            Actual passwords and keys — GITIGNORED, never committed
```

---

## How community charts are deployed

Community charts are pulled directly from their Helm repos at install time.
No local copy is stored. You only keep the overrides file.

```bash
# Add repos once
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add kong https://charts.konghq.com
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add cert-manager https://charts.jetstack.io
helm repo update

# Deploy a community chart with your overrides
helm install postgresql bitnami/postgresql \
  -f overrides/postgresql.yaml \
  -f global-values.yaml \
  -f global-secrets.yaml \
  -n vault
```

## How custom charts are deployed

```bash
helm install vault-api charts/vault-api/ \
  -f global-values.yaml \
  -f global-secrets.yaml \
  -n vault
```

## Deployment order

```
1. cert-manager      no dependencies
2. ingress-nginx     no dependencies
3. postgresql        no dependencies
4. keycloak          needs postgresql
5. kong              needs vault-api to be reachable
6. vault-api         needs postgresql
7. vault-frontend    no dependencies
```
