# SOPS — 06: Kubernetes and Helm Integration

> **Last updated:** July 3, 2026
> **Covers:** helm-secrets plugin, ArgoCD + SOPS, sops-secrets-operator, how secrets get into Kubernetes pods

**20-minute read. This is where SOPS meets production Kubernetes deployments.**

---

## The Kubernetes Secrets Problem

Kubernetes has a `Secret` resource for storing credentials:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vault-api-secrets
  namespace: production
type: Opaque
data:
  database-password: c3VwZXJTZWNyZXQxMjM=   ← base64 encoded (NOT encrypted!)
  jwt-secret: dmVyeS1sb25nLXJhbmRvbS1zZWNyZXQ=
```

**The problem:** Kubernetes Secrets are base64 encoded, NOT encrypted. Anyone who can `kubectl get secret` in that namespace sees the plaintext value. And if you commit this YAML to git — the entire team can decode the base64 in 2 seconds:

```bash
echo "c3VwZXJTZWNyZXQxMjM=" | base64 -d
# superSecret123
```

**The solutions:**
1. `helm-secrets` — SOPS-encrypted Helm values files, decrypted at deploy time
2. ArgoCD + SOPS plugin — decrypt during GitOps sync
3. `sops-secrets-operator` — controller that watches EncryptedSecret CRDs
4. External Secrets Operator — sync from Vault/AWS SM (different approach)

---

## Option 1: helm-secrets Plugin

`helm-secrets` is a Helm plugin that decrypts SOPS-encrypted values files before passing them to Helm.

### Install

```bash
helm plugin install https://github.com/jkroepke/helm-secrets

# Verify
helm secrets version
# 4.6.1 (2026 latest)
```

### Your Encrypted Values File

```yaml
# helm/vault-api/values.secrets.yaml — encrypted with SOPS
secrets:
  databasePassword: ENC[AES256_GCM,data:c3Vw...,type:str]
  jwtSecret: ENC[AES256_GCM,data:dmVy...,type:str]
  stripeApiKey: ENC[AES256_GCM,data:c2tf...,type:str]
sops:
  age:
  - recipient: age1shashank...
    enc: |
      -----BEGIN AGE ENCRYPTED FILE-----
      ...
      -----END AGE ENCRYPTED FILE-----
  lastmodified: "2026-07-03T10:22:31Z"
  version: 3.9.0
```

### Deploy with helm-secrets

```bash
# helm secrets upgrade decrypts the secrets file automatically
helm secrets upgrade vault-app ./helm/vault-api/ \
  --namespace production \
  --install \
  --values helm/vault-api/values.yaml \
  --values helm/vault-api/values.secrets.yaml   ← helm-secrets decrypts this

# What helm-secrets does internally:
# 1. Detects values.secrets.yaml is SOPS-encrypted (sees the sops: block)
# 2. Runs: sops -d values.secrets.yaml > /tmp/values.secrets.yaml.dec
# 3. Runs: helm upgrade ... -f /tmp/values.secrets.yaml.dec
# 4. Deletes the temp file
```

### How the Decrypted Values Become a Kubernetes Secret

Your Helm chart's `templates/secret.yaml`:

```yaml
# helm/vault-api/templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "vault-api.fullname" . }}-secrets
  namespace: {{ .Release.Namespace }}
type: Opaque
stringData:
  DATABASE_PASSWORD: {{ .Values.secrets.databasePassword | quote }}
  JWT_SECRET: {{ .Values.secrets.jwtSecret | quote }}
  STRIPE_API_KEY: {{ .Values.secrets.stripeApiKey | quote }}
```

And in your Deployment:

```yaml
# helm/vault-api/templates/deployment.yaml
envFrom:
- secretRef:
    name: {{ include "vault-api.fullname" . }}-secrets
```

The flow:
```
values.secrets.yaml (SOPS encrypted in git)
  → helm-secrets decrypts at deploy time
  → Helm renders Secret YAML with real values
  → kubectl applies the Secret to Kubernetes
  → Pod reads the Secret as environment variables
```

---

## Option 2: ArgoCD + SOPS (GitOps)

In a GitOps setup, ArgoCD syncs your cluster to your git repo. SOPS integration lets ArgoCD decrypt secrets during sync.

### Install the SOPS Plugin for ArgoCD

```yaml
# argocd-sops-plugin.yaml — add to ArgoCD config
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmp-cm
  namespace: argocd
data:
  plugin.yaml: |
    apiVersion: argoproj.io/v1alpha1
    kind: ConfigManagementPlugin
    metadata:
      name: helm-secrets
    spec:
      version: v1.0
      init:
        command: [sh, -c]
        args:
          - helm dependency build
      generate:
        command: [sh, -c]
        args:
          - |
            helm secrets template \
              "$ARGOCD_APP_NAME" . \
              --namespace "$ARGOCD_APP_NAMESPACE" \
              --values values.yaml \
              --values values.secrets.yaml
      discover:
        find:
          glob: "**/Chart.yaml"
```

### The Age Key in ArgoCD

ArgoCD needs your age private key to decrypt SOPS files during sync:

```bash
# Create the secret with your age private key in ArgoCD's namespace
kubectl create secret generic sops-age-key \
  --from-file=keys.txt=~/.config/sops/age/keys.txt \
  -n argocd

# Mount it in the ArgoCD repo-server pod (via ArgoCD Helm values)
```

```yaml
# ArgoCD Helm values
repoServer:
  volumes:
  - name: sops-age-key
    secret:
      secretName: sops-age-key
  volumeMounts:
  - mountPath: /home/argocd/.config/sops/age/
    name: sops-age-key
  env:
  - name: SOPS_AGE_KEY_FILE
    value: /home/argocd/.config/sops/age/keys.txt
```

### ArgoCD Application Using SOPS

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vault-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/vault-app
    targetRevision: main
    path: helm/vault-api
    plugin:
      name: helm-secrets          ← use the SOPS plugin
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**The flow:**
```
Developer commits encrypted values.secrets.yaml to git
ArgoCD detects the change (webhook or polling)
ArgoCD runs: helm-secrets plugin
  → SOPS decrypts values.secrets.yaml (using age key stored in ArgoCD secret)
  → Helm renders Kubernetes manifests
  → ArgoCD applies manifests to cluster
Secret in cluster has real plaintext values
Pod reads the Secret as env vars
```

---

## Option 3: sops-secrets-operator

A Kubernetes operator that watches for `EncryptedSecret` CRDs and creates real `Secret` objects.

```bash
# Install
helm repo add sops https://isindir.github.io/sops-secrets-operator/
helm install sops-secrets-operator sops/sops-secrets-operator \
  --namespace kube-system
```

```yaml
# Create an EncryptedSecret (you encrypt this file locally with SOPS)
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: vault-api-secrets
  namespace: production
spec:
  secretTemplates:
  - name: vault-api-secrets    ← the real Secret name to create
    labels:
      app: vault-api
    stringData:
      DATABASE_PASSWORD: superSecret123   ← SOPS encrypts this value
      JWT_SECRET: very-long-key
      STRIPE_API_KEY: sk_live_abc123
```

```bash
# Encrypt the SopsSecret file
sops -e -i vault-api-sopssecret.yaml

# Apply to cluster (encrypted)
kubectl apply -f vault-api-sopssecret.yaml

# The operator:
# 1. Sees the new SopsSecret resource
# 2. Decrypts it (using key from its own configuration)
# 3. Creates a real Kubernetes Secret with plaintext values
# 4. Watches for changes — if the encrypted file changes, updates the real Secret
```

**Pros over helm-secrets:**
- Works without Helm (works with plain kubectl apply)
- Operator continuously reconciles (if Secret is deleted, recreates it)
- Native Kubernetes CRD experience

**Cons:**
- Another controller to manage
- Must configure operator's decryption key separately

---

## Comparison: Which Integration to Use?

| Approach | Best For | Limitations |
|----------|---------|------------|
| `helm-secrets` | Helm-based deployments | Only at deploy time; Helm required |
| ArgoCD + SOPS plugin | GitOps teams using ArgoCD | ArgoCD must hold decryption key |
| `sops-secrets-operator` | Non-Helm deployments | Another controller to manage |
| External Secrets Operator | Teams with AWS SM/Vault | Different tool, different approach |

**The most common real-world setup:**
- Small/medium teams: `helm-secrets` — simple, no extra infrastructure
- GitOps teams: ArgoCD + `helm-secrets` plugin
- Large orgs with existing Vault: External Secrets Operator

---

## Practical Directory Structure

```
project/
  .sops.yaml                         ← key configuration (committed)
  
  helm/
    vault-api/
      Chart.yaml
      values.yaml                    ← non-secret config (committed, plaintext)
      values.staging.yaml            ← non-secret staging overrides (committed)
      values.production.yaml         ← non-secret production overrides (committed)
      values.secrets.yaml            ← secrets for dev (SOPS encrypted, committed)
      values.secrets.staging.yaml    ← secrets for staging (SOPS encrypted, committed)
      values.secrets.production.yaml ← secrets for prod (SOPS encrypted, committed)
      templates/
        deployment.yaml
        service.yaml
        secret.yaml                  ← creates k8s Secret from decrypted values
```

---

## The Complete GitOps Flow

```
Developer changes a secret (e.g., rotates Stripe API key):

1. Developer decrypts the file locally:
   sops helm/vault-api/values.secrets.production.yaml
   
2. Updates the Stripe API key in the editor
3. Saves and closes → SOPS re-encrypts
4. Commits: git add && git commit -m "rotate: stripe production api key"
5. Opens a PR (tech lead reviews — can see THAT a change happened, not WHAT)
6. PR merged to main

7. ArgoCD detects the git change
8. ArgoCD runs helm-secrets plugin
9. SOPS decrypts the values file
10. Helm renders the new Kubernetes Secret
11. ArgoCD applies the new Secret to the production cluster
12. Pod picks up the new secret value on next restart (or uses reloader)

Complete audit trail:
  - Git: who changed the encrypted file and when
  - ArgoCD: when it was synced to production
  - CloudTrail (if using KMS): who decrypted the file
  - Kubernetes Events: when the Secret was updated
```

---

## Common Misunderstanding: "ArgoCD will decrypt the file and push plaintext to git"

**The misunderstanding:** "When ArgoCD decrypts my SOPS file, does it commit the plaintext back to git?"

**The reality:** ArgoCD decrypts IN MEMORY during the manifest generation phase. The decrypted content:
1. Is rendered into Kubernetes manifests
2. Applied to the cluster
3. **Never written back to git**
4. The temp decrypted file is deleted immediately

The only place plaintext secrets exist:
- In memory during the ArgoCD sync process
- In the Kubernetes Secret object in etcd (optionally encrypted at rest)
- As environment variables in your running pods

Git always has the encrypted version. ArgoCD never commits anything back to git.

→ Continue to: `07-ci-cd-integration.md`
