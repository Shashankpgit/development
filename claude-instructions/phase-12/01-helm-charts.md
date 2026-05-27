# Phase 12 — Helm Charts

## What this phase covers

Write Helm charts for the vault application services. Use community Helm charts for infrastructure (PostgreSQL, Keycloak, Kong). Tie everything into an umbrella chart. By the end, the entire stack deploys with a single `helm install`.

---

## Pre-step checklist

- [ ] Create `docs/plans/020-helm-plan.md` first
- [ ] Phase 11 complete: images pushed to GHCR
- [ ] Explain what Helm solves BEFORE writing any chart

---

## Why Helm exists

After Phase 13 (deployment), you'll have K8s YAML files for every service. The problem:

- **dev** needs `replicas: 1`, `image: vault-api:dev`
- **production** needs `replicas: 3`, `image: vault-api:abc1234`, different env vars

Without Helm, you either duplicate YAML files (error-prone) or manually edit them for each environment (worse).

Helm solves this with **templating**: one set of templates + different values files for different environments.

Helm also tracks what's deployed: `helm list` shows every release, `helm rollback` goes back to the previous version.

---

## What Helm is (concepts)

### Chart
A packaged K8s application. A directory with templates + default values. Like a `pip` package but for K8s apps.

### Release
A running instance of a chart. `helm install vault-api ./helm/vault-api` creates a release named `vault-api`.

### Values
Variables injected into templates. `values.yaml` has defaults. `values.prod.yaml` overrides for production.

### Template syntax
Go templates. `{{ .Values.api.replicas }}` injects the value. Looks like Jinja2.

### `helm upgrade --install`
The idempotent command: installs if the release doesn't exist, upgrades if it does. Always use this in CI/CD.

---

## Step 1 — Write the vault-api chart

```
helm/
└── vault-api/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        └── configmap.yaml
```

### `Chart.yaml`
```yaml
apiVersion: v2
name: vault-api
description: Personal Vault FastAPI backend
version: 0.1.0
appVersion: "1.0"
```

### `values.yaml`
```yaml
image:
  repository: ghcr.io/YOUR_USERNAME/vault-api
  tag: latest
  pullPolicy: IfNotPresent

replicas: 1

service:
  port: 8000

config:
  appEnv: production
  keycloakUrl: http://keycloak:8080

# Secret values — NOT stored here, passed via --set or external secret
secrets:
  databaseUrl: ""
  vaultEncryptionKey: ""
```

### `templates/deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-api
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.replicas }}
  selector:
    matchLabels:
      app: vault-api
  template:
    metadata:
      labels:
        app: vault-api
    spec:
      containers:
        - name: api
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8000
          env:
            - name: APP_ENV
              value: {{ .Values.config.appEnv }}
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: vault-secrets
                  key: databaseUrl
            - name: VAULT_ENCRYPTION_KEY
              valueFrom:
                secretKeyRef:
                  name: vault-secrets
                  key: vaultEncryptionKey
```

---

## Step 2 — Write the vault-frontend chart

```
helm/
└── vault-frontend/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        └── service.yaml
```

The frontend is the nginx image that serves the React build. Simple Deployment + ClusterIP Service. Ingress routing comes in Step 4.

---

## Step 3 — Use community charts for infrastructure

This is the key real-world lesson: **you don't write PostgreSQL, Keycloak, or Kong manifests from scratch**. Community charts exist for all of these. You configure them.

### Add Helm repos

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add kong https://charts.konghq.com
helm repo update
```

### PostgreSQL — bitnami/postgresql

```bash
helm show values bitnami/postgresql | less   # see all configurable values
```

Create `helm/values/postgresql-values.yaml`:
```yaml
auth:
  username: vault
  password: ""        # passed via --set at install time
  database: vault
  existingSecret: ""  # or use a K8s Secret

primary:
  persistence:
    size: 5Gi

# Keycloak also needs a DB — same PostgreSQL instance, different database
# bitnami supports multiple databases via initdb scripts
```

Deploy:
```bash
helm upgrade --install postgresql bitnami/postgresql \
  --namespace vault \
  --values helm/values/postgresql-values.yaml \
  --set auth.password=strongpassword
```

### Keycloak — bitnami/keycloak

Create `helm/values/keycloak-values.yaml`:
```yaml
auth:
  adminUser: admin
  adminPassword: ""    # passed via --set

postgresql:
  enabled: false       # use our existing PostgreSQL, not a bundled one

externalDatabase:
  host: postgresql
  port: 5432
  user: keycloak
  database: keycloak
  existingSecret: ""

extraVolumes:
  - name: realm-config
    configMap:
      name: keycloak-realm

extraVolumeMounts:
  - name: realm-config
    mountPath: /opt/bitnami/keycloak/data/import
    readOnly: true

extraStartupArgs: "--import-realm"
```

The `realm-export.json` from development becomes a ConfigMap:
```bash
kubectl create configmap keycloak-realm \
  --from-file=realm-export.json=vault/keycloak/realm-export.json \
  -n vault
```

### Kong — kong/kong

Create `helm/values/kong-values.yaml`:
```yaml
env:
  database: "off"           # declarative mode, no database
  declarative_config: /kong/kong.yml

ingressController:
  enabled: false            # we're using K8s Ingress, not Kong Ingress Controller

proxy:
  type: ClusterIP           # internal only, Ingress Controller handles external traffic

volumes:
  - name: kong-config
    configMap:
      name: kong-config

volumeMounts:
  - name: kong-config
    mountPath: /kong
    readOnly: true
```

`kong.yml` becomes a ConfigMap:
```bash
kubectl create configmap kong-config \
  --from-file=kong.yml=vault/kong/kong.yml \
  -n vault
```

---

## Step 4 — Umbrella chart (tie everything together)

An **umbrella chart** is a chart whose only job is to list other charts as dependencies. One `helm install` deploys everything.

```
helm/vault/
├── Chart.yaml          ← lists dependencies
├── values.yaml         ← overrides for all subcharts
└── templates/
    └── namespace.yaml  ← just the namespace resource
```

### `Chart.yaml`
```yaml
apiVersion: v2
name: vault
description: Personal Vault — full stack
version: 0.1.0

dependencies:
  - name: vault-api
    version: "0.1.0"
    repository: "file://../vault-api"    # local chart
  - name: vault-frontend
    version: "0.1.0"
    repository: "file://../vault-frontend"
  - name: postgresql
    version: "15.x.x"
    repository: "https://charts.bitnami.com/bitnami"
  - name: keycloak
    version: "21.x.x"
    repository: "https://charts.bitnami.com/bitnami"
  - name: kong
    version: "2.x.x"
    repository: "https://charts.konghq.com"
```

### `values.yaml`
```yaml
vault-api:
  replicas: 1
  image:
    tag: latest

vault-frontend:
  replicas: 1

postgresql:
  auth:
    username: vault
    database: vault

keycloak:
  auth:
    adminUser: admin
```

### Install everything at once
```bash
helm dependency update helm/vault/   # downloads subchart archives
helm upgrade --install vault helm/vault/ \
  --namespace vault \
  --create-namespace \
  --values helm/vault/values.yaml \
  --set postgresql.auth.password=strongpassword \
  --set keycloak.auth.adminPassword=strongpassword
```

---

## Helm commands to learn

```bash
helm repo add <name> <url>
helm repo update
helm show values <chart>              # inspect all available values
helm upgrade --install <release> <chart>
helm list -n vault                    # all releases in namespace
helm status vault -n vault            # current state
helm rollback vault 1 -n vault        # roll back to revision 1
helm history vault -n vault           # release history
helm template helm/vault/             # render templates without installing (dry run)
helm uninstall vault -n vault
```

---

## What NOT to do in this phase

- Do NOT add TLS/cert-manager yet (that's Phase 15 for GKE)
- Do NOT add Ingress yet (that's Phase 13 — local deployment)
- Do NOT hardcode secrets in values.yaml files (use `--set` or K8s Secrets)

---

## Success criteria

```bash
helm template helm/vault/             # renders valid YAML, no errors

helm lint helm/vault-api/             # chart passes validation
helm lint helm/vault-frontend/
helm lint helm/vault/
```

Charts are written and validated. Ready for Phase 13: deploy to minikube.
