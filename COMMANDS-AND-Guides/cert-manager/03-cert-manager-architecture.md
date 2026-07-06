# Cert-Manager & Let's Encrypt — 03: cert-manager Architecture

> **Last updated:** June 25, 2026
> **Covers:** Components, CRDs, the full internal flow from annotation to working HTTPS

**20-minute read. This is how cert-manager works under the hood.**

---

## cert-manager Components

When you install cert-manager, three pods are created:

```
$ kubectl get pods -n cert-manager

NAME                                       READY   STATUS
cert-manager-7c8d9f7b6-xkj2f              1/1     Running  ← main controller
cert-manager-cainjector-5b9d8f7c6-abc12   1/1     Running  ← CA injector
cert-manager-webhook-6d8c9b7b5-def34      1/1     Running  ← admission webhook
```

### 1. cert-manager (Main Controller)
The brain. It watches Kubernetes resources (Certificate, Issuer, Ingress) and drives the certificate lifecycle — requests, validates, renews.

### 2. cert-manager-cainjector
Injects CA bundle data into webhook configurations. Not directly involved in Let's Encrypt certs. Important for internal PKI setups.

### 3. cert-manager-webhook
A Kubernetes admission webhook. Validates cert-manager resources when you create/update them — catches misconfigurations before they're applied. Also provides conversion between API versions.

---

## cert-manager CRDs (Custom Resource Definitions)

cert-manager adds these custom resources to Kubernetes:

```
ClusterIssuer     — how to issue certificates (cluster-wide)
Issuer            — how to issue certificates (namespace-scoped)
Certificate       — a request for a certificate
CertificateRequest — one-time cert signing request (cert-manager creates these)
Order             — an ACME order (cert-manager creates these)
Challenge         — an ACME challenge (cert-manager creates these)
```

You interact with: **ClusterIssuer, Issuer, Certificate**
cert-manager manages internally: **CertificateRequest, Order, Challenge**

---

## The CRD Hierarchy

```
ClusterIssuer
  "letsencrypt-prod"            ← you create this
  (knows how to talk to ACME)
  │
  │ referenced by
  ▼
Certificate
  "vault-api-tls"               ← you create this (or ingress triggers it)
  (describes what cert you want)
  │
  │ cert-manager creates
  ▼
CertificateRequest
  (one-time signing request)
  │
  │ cert-manager creates
  ▼
Order
  (ACME order with Let's Encrypt)
  │
  │ Let's Encrypt responds with
  ▼
Challenge
  (HTTP-01 or DNS-01 challenge)
  │
  │ cert-manager completes
  ▼
Certificate signed and stored as
  Secret: vault-api-tls
```

---

## ClusterIssuer — The Bridge to Let's Encrypt

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Let's Encrypt production ACME server
    server: https://acme-v02.api.letsencrypt.org/directory
    
    # Email for expiry notifications from Let's Encrypt
    email: devops@vault.example.com
    
    # Where cert-manager stores the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    
    # How to solve domain ownership challenges
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx   # which ingress controller handles the challenge
```

**What `privateKeySecretRef` is:**
When cert-manager first registers with Let's Encrypt, it creates an ACME account and generates a private key for that account. That key proves you are the same entity across all certificate requests. cert-manager stores it in the named Secret.

You don't manage this key — cert-manager creates it automatically.

---

## Certificate — What You Want

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-api-tls
  namespace: production
spec:
  # The Secret where cert-manager will store the issued cert
  secretName: vault-api-tls
  
  # Domains this certificate covers
  dnsNames:
  - api.vault.example.com
  - vault.example.com
  
  # Which Issuer to use
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

When cert-manager processes this, it:
1. Talks to Let's Encrypt via the ClusterIssuer
2. Runs the challenge for each domain in `dnsNames`
3. Stores the resulting cert + key in Secret `vault-api-tls` in namespace `production`

---

## The Ingress Annotation Shortcut

You don't always need to create a Certificate resource manually. If you add an annotation to your Ingress, cert-manager creates the Certificate resource automatically:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault-api-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod   # ← this annotation
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.vault.example.com
    secretName: vault-api-tls    # ← cert-manager creates this Secret
  rules:
  - host: api.vault.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vault-api
            port:
              number: 3000
```

cert-manager sees this Ingress and:
1. Reads the `cert-manager.io/cluster-issuer: letsencrypt-prod` annotation
2. Reads the `spec.tls` section (domain + secretName)
3. Creates a Certificate resource automatically
4. The Certificate resource triggers the full ACME flow
5. The resulting cert is stored in `vault-api-tls`
6. nginx uses that Secret for TLS termination

This is the most common pattern in practice — you never write a Certificate YAML directly.

---

## Complete Internal Flow: Annotation → Working HTTPS

Let's trace everything from the moment you `kubectl apply -f ingress.yaml`:

```
1. YOU apply the Ingress YAML
   kubectl apply -f ingress.yaml

2. cert-manager controller watches Ingress resources
   Sees annotation: cert-manager.io/cluster-issuer: letsencrypt-prod
   Creates Certificate object:
     name: vault-api-tls
     namespace: production
     dnsNames: [api.vault.example.com]
     issuerRef: letsencrypt-prod (ClusterIssuer)

3. cert-manager processes the Certificate
   Creates CertificateRequest object
   (a pending request to sign a CSR)

4. cert-manager processes the CertificateRequest
   Generates a private key (RSA 2048 or ECDSA P-256)
   Creates a CSR (Certificate Signing Request)
   Sends the CSR to Let's Encrypt

5. Let's Encrypt creates an Order
   Returns challenge requirements:
   "Prove ownership of api.vault.example.com"
   Via http-01: place file at /.well-known/acme-challenge/<token>

6. cert-manager processes the Order
   Creates Challenge object
   Starts an ACME solver pod
   Creates temporary Ingress pointing to solver pod

7. cert-manager marks Challenge as Ready
   Let's Encrypt checks: GET api.vault.example.com/.well-known/...
   Gets correct response → Challenge validated

8. cert-manager finalizes the Order
   Let's Encrypt issues the certificate
   cert-manager downloads the certificate

9. cert-manager stores the certificate
   Creates/updates Secret vault-api-tls:
     tls.crt: <certificate + chain>
     tls.key: <private key>

10. cert-manager marks Certificate as Ready
    cert-manager deletes the temporary Ingress and solver pod

11. nginx ingress controller detects Secret vault-api-tls updated
    Reloads nginx configuration with the new certificate

12. HTTPS is working
    Users can now hit https://api.vault.example.com

Total time: approximately 30-90 seconds
```

---

## Watching the Flow in Real Time

```bash
# Watch all cert-manager events
kubectl get events -n production --field-selector reason=Issued
kubectl get events -n production --field-selector reason=OrderCreated

# Watch the certificate status
kubectl describe certificate vault-api-tls -n production

# Watch orders (cert-manager creates these)
kubectl get orders -n production
kubectl describe order vault-api-tls-<hash> -n production

# Watch challenges
kubectl get challenges -n production
kubectl describe challenge vault-api-tls-<hash> -n production

# Watch cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f
```

**What you see in `kubectl describe certificate`:**

```
Name:         vault-api-tls
Namespace:    production
...
Status:
  Conditions:
    Message:               Certificate is up to date and has not expired
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2026-08-30T10:22:31Z
  Not Before:              2026-06-01T10:22:31Z
  Renewal Time:            2026-07-31T10:22:31Z   ← auto-renews 30 days before expiry
  Revision:                1
Events:
  Normal  Issuing    2m    cert-manager  Issuing certificate as Secret does not exist
  Normal  Generated  2m    cert-manager  Stored new private key in temporary Secret
  Normal  Requested  2m    cert-manager  Created new CertificateRequest resource
  Normal  Issuing    30s   cert-manager  The certificate has been successfully issued
```

---

## ClusterIssuer vs Issuer

| | ClusterIssuer | Issuer |
|--|--------------|--------|
| Scope | Cluster-wide | Single namespace |
| Annotation | `cert-manager.io/cluster-issuer: name` | `cert-manager.io/issuer: name` |
| Use case | Most common — one issuer for all namespaces | Per-team CA, namespace isolation |
| Where ACME key stored | In cert-manager namespace | In same namespace as Issuer |

**When to use Issuer instead of ClusterIssuer:**
- Different teams need different CA roots
- Namespace-isolated environments with different Let's Encrypt accounts
- Testing in one namespace without affecting others

In practice: **use ClusterIssuer** for Let's Encrypt. Use Issuer only for complex multi-tenant setups.

---

## Certificate Conditions (Health Status)

```bash
kubectl get certificates -A   # list all certs with their status

# Output:
NAMESPACE    NAME           READY   SECRET         AGE
production   vault-api-tls  True    vault-api-tls  10d
staging      api-staging    True    api-staging    3d
```

**READY=True** → Certificate is valid and stored in the Secret.
**READY=False** → Something is wrong. `kubectl describe certificate <name>` for details.

---

## Common Misunderstanding: "I need to watch for cert expiry manually"

**The misunderstanding:** "I should set up a Prometheus alert for certificate expiry."

**The reality:** cert-manager handles renewal automatically. You should NOT need to set up expiry alerts for cert-manager-managed certs.

However: you should monitor that cert-manager itself is healthy. If the cert-manager pod crashes, renewals stop.

What to monitor:
```
# Useful Prometheus metrics from cert-manager:
certmanager_certificate_expiration_timestamp_seconds   ← time until expiry
certmanager_certificate_ready_status                   ← is it Ready?
certmanager_http_acme_client_request_duration_seconds  ← ACME API latency

# Useful alerts:
- Certificate with READY=False for >10 minutes
- Certificate expiring in <7 days (cert-manager failed to renew)
- cert-manager pod not running
```

The cert-manager project ships a Grafana dashboard and Prometheus rules — use those.

→ Continue to: `04-installation.md`
