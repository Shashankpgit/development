# GKE Setup Guide

Everything you need to create and configure a GKE cluster before we start deploying.

---

## What you need before starting

- GCP account (you already have one — used it for the VM)
- Billing enabled on the project (already done)
- Domain: `vaultpraja.duckdns.org` (already have it)

---

## Cost estimate

GKE Standard with 1 × `e2-standard-2` node (2 vCPU, 8GB RAM):
- ~$48/month for the node
- GKE control plane: free for 1 zonal cluster
- Persistent disk (PostgreSQL): ~$1/month

This node size is enough for the full vault stack (PostgreSQL + Keycloak + Kong + API + Frontend).

> If you want to keep costs low during learning, use `e2-medium` (1 vCPU, 4GB RAM) at ~$24/month. Keycloak is memory-hungry (~1GB alone), so `e2-medium` will be tight but workable.

---

## Step 1 — Enable required GCP APIs

Go to GCP Console → APIs & Services → Enable APIs, and enable these:

| API | Why |
|---|---|
| Kubernetes Engine API | To create and manage GKE clusters |
| Compute Engine API | GKE nodes are Compute Engine VMs |

That's it. We're using GHCR for images — GKE pods can pull from any registry directly. Container Registry API is only needed if you were using Google's own registry (`gcr.io`).

Or run in Cloud Shell:
```bash
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
```

---

## Step 2 — Install gcloud CLI (on your local machine)

We need gcloud CLI only to connect kubectl to GKE. The cluster itself is created via Console.

```bash
# Download and install
curl https://sdk.cloud.google.com | bash

# Restart shell
exec -l $SHELL

# Verify
gcloud version
```

---

## Step 3 — Authenticate and set project

```bash
# Login with your Google account
gcloud auth login

# List your projects (find the one your VM is in)
gcloud projects list

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Verify
gcloud config get-value project
```

---

## Step 4 — Create the GKE cluster (via GCP Console)

> Infra will be automated via Terraform in a later phase. For now, create via Console.

Go to: **GCP Console → Kubernetes Engine → Clusters → Create**

When prompted, choose **Standard** (not Autopilot). Autopilot manages nodes automatically but gives less control and is harder to learn from.

---

### Tab: Cluster basics

| Field | Value | Why |
|---|---|---|
| Name | `vault-cluster` | |
| Location type | `Zonal` | Cheaper than Regional (Regional = 3 zones = 3× cost) |
| Zone | same zone as your existing VM | e.g. `us-central1-a` — keeps network latency low |
| Release channel | `Regular` | Stable K8s version, not bleeding edge |

---

### Tab: default-pool → Details

| Field | Value | Why |
|---|---|---|
| Name | `default-pool` | leave as is |
| Number of nodes | `1` | One worker node — enough for the full vault stack |

---

### Tab: default-pool → Nodes

| Field | Value | Why |
|---|---|---|
| Image type | `Container-Optimized OS with containerd (cos_containerd)` | GCP's recommended, most secure node OS |
| Machine configuration | `General purpose` | |
| Series | `E2` | Cost-effective general purpose |
| Machine type | `e2-standard-2` | 2 vCPU, 8 GB RAM — fits PostgreSQL + Keycloak + Kong + API + Frontend |
| Boot disk type | `Balanced persistent disk` | Good balance of cost and performance |
| Boot disk size | `30 GB` | Enough for OS + container images |
| Enable nodes on spot VMs | `OFF` | Spot VMs are cheap but can be terminated anytime — not for learning |

---

### Tab: default-pool → Security

| Field | Value | Why |
|---|---|---|
| Access scopes | `Allow full access to all Cloud APIs` | Simplifies permissions during learning |

---

### Tab: Cluster → Networking

| Field | Value |
|---|---|
| Network | `default` |
| Node subnet | `default` |
| Enable HTTP load balancing | `ON` (checked) |

Everything else leave as default.

---

### Click **Create**

Takes **3-5 minutes**. GCP is provisioning a VM, installing K8s on it, and setting up the control plane.

Once the cluster shows a green checkmark (Running), come back for the next step.

---

## Step 5 — Configure kubectl to talk to GKE

```bash
gcloud container clusters get-credentials vault-cluster \
  --zone us-central1-a

# Verify kubectl is pointing to GKE
kubectl get nodes
# NAME                                          STATUS   ROLES    AGE
# gke-vault-cluster-default-pool-xxx-xxx        Ready    <none>   2m
```

`get-credentials` writes a kubeconfig entry on your local machine. kubectl now talks to GKE instead of minikube.

---

## Step 6 — Create the vault namespace

```bash
kubectl create namespace vault

# Verify
kubectl get namespaces
```

---

## Step 7 — Install nginx Ingress Controller

This replaces the nginx container you had in docker-compose. It handles all incoming HTTP/HTTPS traffic and routes it based on Ingress rules.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

Wait ~2 minutes, then get the external IP:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# NAME                       TYPE           CLUSTER-IP    EXTERNAL-IP
# ingress-nginx-controller   LoadBalancer   10.x.x.x     34.x.x.x    ← this is your cluster's public IP
```

**Copy this external IP** — you'll point your domain to it in the next step.

---

## Step 8 — Point domain to the cluster

Go to **duckdns.org** → update `vaultpraja` → set IP to the external IP from Step 7.

Verify DNS has propagated:
```bash
ping vaultpraja.duckdns.org
# should resolve to the GKE external IP
```

---

## Step 9 — Install cert-manager

cert-manager automates TLS certificate issuance from Let's Encrypt. It replaces the manual certbot you ran on the VM.

```bash
helm repo add cert-manager https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager cert-manager/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Verify (wait ~1 min)
kubectl get pods -n cert-manager
# cert-manager-xxx            Running
# cert-manager-cainjector-xxx Running
# cert-manager-webhook-xxx    Running
```

---

## Step 10 — Create a Let's Encrypt ClusterIssuer

This tells cert-manager how to get TLS certs (via Let's Encrypt ACME):

```bash
kubectl apply -f - <<EOF
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
EOF

# Verify
kubectl get clusterissuer
# NAME               READY
# letsencrypt-prod   True
```

Replace `your-email@example.com` with your real email — Let's Encrypt uses it for expiry notifications.

---

## Final checklist — confirm before moving forward

```bash
# 1. GKE cluster running
kubectl get nodes
# → 1 node, STATUS: Ready

# 2. Ingress controller with external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
# → EXTERNAL-IP: 34.x.x.x (not <pending>)

# 3. Domain resolves to cluster IP
ping vaultpraja.duckdns.org
# → 34.x.x.x (matches above)

# 4. cert-manager running
kubectl get pods -n cert-manager
# → 3 pods Running

# 5. ClusterIssuer ready
kubectl get clusterissuer
# → letsencrypt-prod   True

# 6. vault namespace exists
kubectl get namespace vault
# → Active
```

All 6 checks pass → cluster is ready for deployment.
