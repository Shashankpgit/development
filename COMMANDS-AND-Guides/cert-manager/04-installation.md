# Cert-Manager & Let's Encrypt — 04: Installation and First Setup

> **Last updated:** June 25, 2026
> **Covers:** Installing cert-manager, creating your first ClusterIssuer, verifying everything works

**20-minute read. By the end of this file, cert-manager is running and your first test certificate is issued.**

---

## Prerequisites

Before installing cert-manager:
- Kubernetes cluster running (EKS, GKE, k3s, etc.)
- `kubectl` configured and working
- `helm` v3 installed
- An ingress controller running (nginx is most common)
- A domain name with DNS pointing to your cluster

---

## Option 1: Install via Helm (Recommended)

```bash
# Add the cert-manager Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
# --set installCRDs=true installs the CRD definitions in the same command
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.3 \
  --set installCRDs=true

# Verify the installation
kubectl get pods -n cert-manager
```

Expected output (all 3 pods Running):
```
NAME                                       READY   STATUS    RESTARTS
cert-manager-7c8d9f7b6-xkj2f              1/1     Running   0
cert-manager-cainjector-5b9d8f7c6-abc12   1/1     Running   0
cert-manager-webhook-6d8c9b7b5-def34      1/1     Running   0
```

---

## Option 2: Install via Static Manifest

```bash
# For the exact cert-manager version you want to pin
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.yaml

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager --timeout=120s
```

---

## Option 3: Install via Helm Values File (Recommended for GitOps)

```yaml
# helm/cert-manager/values.yaml
installCRDs: true
replicaCount: 2                    # high availability
podDisruptionBudget:
  enabled: true                    # don't evict all replicas at once

# Enable Prometheus metrics
prometheus:
  enabled: true
  servicemonitor:
    enabled: true                  # for Prometheus Operator users

# Resource limits (adjust for your cluster)
resources:
  requests:
    cpu: 10m
    memory: 32Mi
  limits:
    cpu: 500m
    memory: 256Mi

# Webhook resources
webhook:
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 64Mi
```

```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.3 \
  --values helm/cert-manager/values.yaml
```

---

## Step 2: Create the ClusterIssuer (Staging First)

**ALWAYS start with staging.** You get unlimited test certificates, and mistakes won't hit Let's Encrypt production rate limits.

```yaml
# cert-manager/cluster-issuer-staging.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # STAGING server - unlimited certs, but not trusted by browsers
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    
    # Let's Encrypt uses this for important notifications (cert expiry warnings)
    email: devops@vault.example.com
    
    # cert-manager stores the ACME account key here
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx    # must match your ingress controller
```

```bash
kubectl apply -f cert-manager/cluster-issuer-staging.yaml

# Verify it's ready
kubectl describe clusterissuer letsencrypt-staging
```

Look for:
```
Status:
  Acme:
    Uri: https://acme-staging-v02.api.letsencrypt.org/acme/acct/123456789
  Conditions:
    Message:  The ACME account was registered with the ACME server
    Reason:   ACMEAccountRegistered
    Status:   True
    Type:     Ready
```

If Status is Ready=True → cert-manager successfully registered with Let's Encrypt. 

---

## Step 3: Create the Production ClusterIssuer

```yaml
# cert-manager/cluster-issuer-production.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # PRODUCTION server - rate limited, trusted by browsers
    server: https://acme-v02.api.letsencrypt.org/directory
    email: devops@vault.example.com
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx
```

```bash
kubectl apply -f cert-manager/cluster-issuer-production.yaml
kubectl get clusterissuer

# Output:
NAME                  READY   AGE
letsencrypt-prod      True    5s
letsencrypt-staging   True    2m
```

---

## Step 4: Test With a Real Certificate (Staging)

Create a test Ingress in a non-production namespace:

```yaml
# test-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging   # staging first
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - test.vault.example.com       # must be your real domain
    secretName: test-tls
  rules:
  - host: test.vault.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: your-service     # must exist
            port:
              number: 80
```

```bash
kubectl apply -f test-ingress.yaml

# Watch cert-manager issue the certificate
kubectl get certificate -n default -w

# Should go from False to True in ~60 seconds:
# NAME       READY   SECRET     AGE
# test-tls   False   test-tls   5s
# test-tls   True    test-tls   62s
```

---

## Verifying the Certificate

```bash
# Check the certificate details
kubectl describe certificate test-tls -n default

# Check what's in the Secret
kubectl get secret test-tls -n default -o yaml

# Decode the certificate (to see expiry, domains, etc.)
kubectl get secret test-tls -n default \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Output includes:
# Issuer: C=US, O=Let's Encrypt, CN=Let's Encrypt E5  (staging CA)
# Subject: CN=test.vault.example.com
# Not After: Aug 30 10:22:31 2026 GMT
# X509v3 Subject Alternative Names: DNS:test.vault.example.com
```

For staging certs, you'll see "Fake LE Root X1" or similar in the issuer — that's expected. The mechanism works; you just need to switch to production for a trusted cert.

---

## Switching to Production

Once staging works:

```yaml
# Update the annotation in your Ingress
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod   # ← change this
```

```bash
kubectl apply -f ingress.yaml

# Delete the staging Secret so cert-manager creates a new production one
kubectl delete secret test-tls -n default

# Watch the new cert get issued (now from the production CA)
kubectl get certificate test-tls -n default -w
```

---

## cmctl — The cert-manager CLI

cert-manager has its own CLI for debugging:

```bash
# Install cmctl
curl -L -o cmctl https://github.com/cert-manager/cmctl/releases/latest/download/cmctl_linux_amd64
chmod +x cmctl && sudo mv cmctl /usr/local/bin/

# Check cert-manager installation health
cmctl check api

# Manually trigger a certificate renewal
cmctl renew vault-api-tls -n production

# Convert certificate to different formats
cmctl convert -f certificate.yaml

# Inspect an existing certificate
cmctl inspect secret vault-api-tls -n production
```

---

## Helm Values for Different Environments

```yaml
# helm/cert-manager/values.staging.yaml
replicaCount: 1   # staging: save resources

# helm/cert-manager/values.production.yaml
replicaCount: 2   # production: high availability
podDisruptionBudget:
  enabled: true
priorityClassName: system-cluster-critical   # don't evict cert-manager
```

```bash
# Deploy staging
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --values helm/cert-manager/values.yaml \
  --values helm/cert-manager/values.staging.yaml

# Deploy production
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --values helm/cert-manager/values.yaml \
  --values helm/cert-manager/values.production.yaml
```

---

## Common Misunderstanding: "I should create the Secret manually first"

**The misunderstanding:** "I need to create the `vault-api-tls` Secret before cert-manager can use it."

**The reality:** cert-manager CREATES the Secret. You never create it manually. When you create a Certificate resource (or annotate an Ingress), cert-manager creates the Secret automatically after the ACME challenge succeeds.

If you pre-create the Secret:
- cert-manager may refuse to overwrite it
- You'll see errors like "secret already exists"

Exception: if you're migrating from another cert solution (like certbot), you can pre-populate the Secret with the existing cert. cert-manager will use it and handle renewal from there. But for new setups: let cert-manager create it.

→ Continue to: `05-http01-in-practice.md`
