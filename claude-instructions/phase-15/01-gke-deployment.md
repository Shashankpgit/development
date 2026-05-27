# Phase 15 — Deploy to GKE (Production)

## What this phase covers

Provision a GKE (Google Kubernetes Engine) cluster. Deploy the full vault stack to production using the same Helm charts from Phase 12-13. Add cert-manager for automatic TLS. Point `vaultpraja.duckdns.org` to the cluster. Retire the VM + docker-compose deployment.

---

## Pre-step checklist

- [ ] Create `docs/plans/023-gke-deployment-plan.md` first
- [ ] Phase 14 complete: CI/CD pipeline builds and pushes images
- [ ] GCP account with billing enabled (GKE is not free tier)
- [ ] Existing domain: `vaultpraja.duckdns.org`

---

## Why GKE instead of the current VM

The current VM runs docker-compose. It's a single machine — single point of failure. If it crashes, the app is gone. Scaling means logging into the VM manually.

GKE is Google's managed Kubernetes. Google manages the control plane (free). You pay only for worker nodes. Benefits:
- **Managed control plane**: Google handles etcd, API server, upgrades
- **Auto-repair**: failed nodes are replaced automatically
- **Autopilot mode**: Google manages node scaling too (simplest option)
- **Integration with GCP**: load balancers, persistent disks, private registry all native

---

## What's different from minikube

| minikube | GKE |
|---|---|
| HTTP only | HTTPS with real cert |
| `vault.local` (fake domain) | `vaultpraja.duckdns.org` (real domain) |
| Manual `minikube start` | GKE cluster provisioned via `gcloud` |
| Port-forward or NodePort | Real LoadBalancer (external IP) |
| No cert-manager | cert-manager + Let's Encrypt |
| Docker driver | Real VMs (nodes) |

---

## Step 1 — Provision GKE cluster

```bash
# Install gcloud CLI
# Then authenticate
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Create GKE Autopilot cluster (simplest — Google manages nodes)
gcloud container clusters create-auto vault-cluster \
  --region us-central1

# Get credentials (configures kubectl to talk to GKE)
gcloud container clusters get-credentials vault-cluster \
  --region us-central1

# Verify
kubectl get nodes
# → GKE nodes appear (Autopilot provisions them on demand)
```

---

## Step 2 — Install cert-manager

cert-manager is a K8s operator that:
1. Watches for `Certificate` resources you create
2. Automatically does the ACME challenge with Let's Encrypt
3. Stores the issued cert as a K8s Secret
4. Renews before expiry (automatically)

This replaces everything certbot did on the VM — completely automated.

```bash
# Add cert-manager Helm repo
helm repo add cert-manager https://charts.jetstack.io
helm repo update

# Install cert-manager
helm upgrade --install cert-manager cert-manager/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### Create a ClusterIssuer

A `ClusterIssuer` tells cert-manager how to issue certs (which CA, which challenge method):

```yaml
# helm/vault/templates/cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

---

## Step 3 — Update Ingress for HTTPS

Add TLS to the Ingress and reference the ClusterIssuer:

```yaml
# helm/vault/templates/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault
  namespace: vault
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod   # ← triggers cert issuance
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - vaultpraja.duckdns.org
      secretName: vault-tls-cert              # cert-manager creates this Secret
  rules:
    - host: vaultpraja.duckdns.org
      http:
        paths:
          - path: /api/
            ...
          - path: /realms/
            ...
          - path: /
            ...
```

cert-manager sees the annotation, runs the ACME HTTP-01 challenge via the Ingress, gets the cert from Let's Encrypt, stores it in the `vault-tls-cert` Secret. nginx Ingress Controller picks it up and serves HTTPS.

---

## Step 4 — Production values file

`helm/vault/values.prod.yaml`:
```yaml
vault-api:
  replicas: 2
  image:
    tag: ""          # overridden by CI/CD with SHA

vault-frontend:
  replicas: 2

keycloak:
  # KC_HOSTNAME must match real domain
  extraEnvVars:
    - name: KC_HOSTNAME
      value: vaultpraja.duckdns.org

ingress:
  host: vaultpraja.duckdns.org
  tls: true
```

---

## Step 5 — Update CI/CD for GKE deploy

Add GKE deploy step to `.github/workflows/ci.yml`:

```yaml
deploy:
  needs: build-and-push
  runs-on: ubuntu-latest
  if: github.ref == 'refs/heads/main'

  steps:
    - uses: actions/checkout@v4

    - uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GKE_SA_KEY }}

    - uses: google-github-actions/get-gke-credentials@v2
      with:
        cluster_name: ${{ secrets.GKE_CLUSTER }}
        location: ${{ secrets.GKE_REGION }}

    - uses: azure/setup-helm@v3

    - name: Deploy to GKE
      run: |
        helm upgrade --install vault helm/vault/ \
          --namespace vault \
          --create-namespace \
          --values helm/vault/values.prod.yaml \
          --set vault-api.image.tag=${{ github.sha }} \
          --set vault-frontend.image.tag=${{ github.sha }}
```

---

## Step 6 — Point domain to cluster

```bash
# Get the external IP of the nginx Ingress Controller
kubectl get svc -n ingress-nginx ingress-nginx-controller
# EXTERNAL-IP: 34.x.x.x

# Update DuckDNS to point to the new IP
# Go to duckdns.org → update vaultpraja → set IP to 34.x.x.x
```

---

## What to retire after this phase

The old GCP VM (`8.231.93.159`) running docker-compose can be stopped. Everything it was doing (nginx, Kong, Keycloak, API, PostgreSQL) now runs in GKE.

---

## Success criteria

```bash
# Push to main → GitHub Actions deploys to GKE

# Verify
kubectl get pods -n vault               # all running in GKE
kubectl get ingress -n vault            # shows vaultpraja.duckdns.org with ADDRESS

# Certificate issued
kubectl get certificate -n vault
# → vault-tls-cert   True   (Ready = True means cert is issued)

# Browser
# https://vaultpraja.duckdns.org → app loads with green padlock
# Full flow: register → login → create note → delete note
```
