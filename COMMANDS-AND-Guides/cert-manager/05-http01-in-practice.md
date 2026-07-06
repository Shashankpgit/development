# Cert-Manager & Let's Encrypt — 05: HTTP-01 in Practice

> **Last updated:** June 25, 2026
> **Covers:** Complete end-to-end setup, real manifests, multi-service setup, troubleshooting HTTP-01

**20-minute read. This is the most common setup — public cluster, nginx ingress, Let's Encrypt.**

---

## The Complete Setup

You have a Kubernetes cluster on AWS EKS with:
- nginx ingress controller running
- DNS pointing to the nginx ingress Load Balancer IP
- Your app deployed as a Deployment + Service

Let's secure it end-to-end.

---

## Step 1: Verify nginx ingress is reachable

```bash
# Get the nginx Load Balancer address
kubectl get service -n ingress-nginx ingress-nginx-controller

# Output:
NAME                       TYPE           EXTERNAL-IP
ingress-nginx-controller   LoadBalancer   a3f2b1c4d5.ap-south-1.elb.amazonaws.com

# Test that port 80 is accessible (required for HTTP-01)
curl -I http://a3f2b1c4d5.ap-south-1.elb.amazonaws.com
# Should get some response (even a 404 is fine — proves port 80 is open)
```

```bash
# Verify your DNS points to this address
dig api.vault.example.com
# Should resolve to the Load Balancer address (or its IP)
```

---

## Step 2: Your App Manifests

```yaml
# vault-api/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-api
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: vault-api
  template:
    metadata:
      labels:
        app: vault-api
    spec:
      containers:
      - name: vault-api
        image: your-registry/vault-api:v1.0.0
        ports:
        - containerPort: 3000
```

```yaml
# vault-api/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: vault-api
  namespace: production
spec:
  selector:
    app: vault-api
  ports:
  - port: 80
    targetPort: 3000
```

---

## Step 3: The Ingress with TLS

```yaml
# vault-api/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault-api-ingress
  namespace: production
  annotations:
    # This is the magic annotation — cert-manager watches for this
    cert-manager.io/cluster-issuer: letsencrypt-prod
    
    # nginx-specific configuration (optional but useful)
    nginx.ingress.kubernetes.io/ssl-redirect: "true"       # redirect HTTP→HTTPS
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"     # max request body
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"   # timeout
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.vault.example.com
    secretName: vault-api-tls           # cert-manager will create this
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
              number: 80
```

```bash
# Apply everything
kubectl apply -f vault-api/deployment.yaml
kubectl apply -f vault-api/service.yaml
kubectl apply -f vault-api/ingress.yaml

# Watch the certificate get issued
kubectl get certificate -n production -w
```

---

## Step 4: What Happens Next (Automated)

```
T+0s   You apply the Ingress YAML

T+1s   cert-manager sees the Ingress with annotation
       Creates Certificate: vault-api-tls in namespace production

T+2s   cert-manager creates CertificateRequest
       Generates a private key
       Builds a CSR for api.vault.example.com

T+5s   cert-manager POSTs to Let's Encrypt ACME
       Receives challenge: serve file at /.well-known/acme-challenge/<token>

T+7s   cert-manager creates temporary resources:
       Pod: cm-acme-http-solver-<random>
       Service: cm-acme-http-solver-<random>
       Ingress: cm-acme-http-solver-<random>
       (the Ingress routes /.well-known/... to the solver pod)

T+15s  cert-manager tells Let's Encrypt: "I'm ready"

T+20s  Let's Encrypt makes HTTP request to api.vault.example.com
       GET /.well-known/acme-challenge/<token>
       Gets correct response from solver pod

T+30s  Let's Encrypt: challenge passed
       Issues the certificate

T+35s  cert-manager downloads the certificate
       Stores in Secret vault-api-tls:
         tls.crt: certificate + chain
         tls.key: private key

T+40s  cert-manager deletes the temporary pod/service/ingress

T+42s  nginx detects Secret vault-api-tls was created/updated
       Hot-reloads its TLS configuration

T+45s  https://api.vault.example.com is working ✓
```

---

## Multiple Services on the Same Domain

You have multiple services under `vault.example.com`:

```
api.vault.example.com      → vault-api service
app.vault.example.com      → vault-frontend service
admin.vault.example.com    → vault-admin service
```

You can use one certificate with multiple SANs, or separate certificates per subdomain. Here's both approaches:

### Approach 1: Separate certs per service (recommended)
Each Ingress manages its own cert. They renew independently.

```yaml
# api-ingress.yaml
spec:
  tls:
  - hosts: [api.vault.example.com]
    secretName: vault-api-tls

# frontend-ingress.yaml
spec:
  tls:
  - hosts: [app.vault.example.com]
    secretName: vault-frontend-tls

# admin-ingress.yaml
spec:
  tls:
  - hosts: [admin.vault.example.com]
    secretName: vault-admin-tls
```

### Approach 2: One cert for all subdomains (multi-SAN)
```yaml
# Create a Certificate resource directly
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-multi-tls
  namespace: production
spec:
  secretName: vault-multi-tls
  dnsNames:
  - api.vault.example.com
  - app.vault.example.com
  - admin.vault.example.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

```yaml
# Then reference the same Secret in all Ingresses
# api-ingress.yaml
spec:
  tls:
  - hosts: [api.vault.example.com]
    secretName: vault-multi-tls    # same secret

# frontend-ingress.yaml
spec:
  tls:
  - hosts: [app.vault.example.com]
    secretName: vault-multi-tls    # same secret
```

Trade-off: Multi-SAN cert means one renewal touches all services. Separate certs mean each service is independent.

---

## HTTP to HTTPS Redirect

You almost always want HTTP traffic to redirect to HTTPS. The nginx annotation handles this:

```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

What this does:
```
User hits: http://api.vault.example.com/api/auth
nginx returns: HTTP 308 Permanent Redirect → https://api.vault.example.com/api/auth
Browser follows redirect: hits HTTPS version
```

**One important scenario to handle:** during the ACME challenge, Let's Encrypt makes HTTP requests to `/.well-known/acme-challenge/`. The redirect must NOT apply to this path.

cert-manager handles this automatically — its temporary Ingress is more specific than your redirect Ingress, so nginx routes the challenge correctly without the redirect. You don't need to worry about this.

---

## Troubleshooting HTTP-01

### Certificate stuck at READY=False

```bash
# Step 1: Check the Certificate events
kubectl describe certificate vault-api-tls -n production

# Step 2: Check the Order
kubectl get orders -n production
kubectl describe order vault-api-tls-<hash> -n production

# Step 3: Check the Challenge
kubectl get challenges -n production
kubectl describe challenge vault-api-tls-<hash>-<hash> -n production
```

### Challenge fails with "DNS problem"
```
Error: DNS problem: NXDOMAIN looking up A for api.vault.example.com
```

**Cause:** DNS isn't pointing to your cluster yet.
**Fix:** Create the DNS A record pointing to your nginx Load Balancer IP.

```bash
# Find your nginx LoadBalancer IP/hostname
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Create A record or CNAME in your DNS provider
```

### Challenge fails with "Connection refused" or timeout
```
Error: Failed to perform http-01 challenge: connection refused on port 80
```

**Cause:** Port 80 isn't accessible. Could be:
- Security group / firewall blocks port 80
- nginx ingress isn't listening on port 80
- Challenge solver pod not running

```bash
# Check if port 80 is accessible
curl -v http://api.vault.example.com/.well-known/acme-challenge/test

# Check the temporary ingress was created
kubectl get ingress -n production  # look for cm-acme-http-solver-*

# Check the solver pod is running
kubectl get pods -n production | grep cm-acme-http-solver
```

### Challenge passes but certificate never stored

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

Common cause: RBAC issue — cert-manager can't create Secrets in your namespace.

```bash
# Check if cert-manager has permission to create secrets in your namespace
kubectl auth can-i create secrets --as=system:serviceaccount:cert-manager:cert-manager -n production
```

If "no" → you have an RBAC issue. cert-manager needs ClusterRole permissions by default — this usually means the installation is incomplete.

---

## Force a Manual Renewal

```bash
# Method 1: Using cmctl
cmctl renew vault-api-tls -n production

# Method 2: Annotate the certificate to force renewal
kubectl annotate certificate vault-api-tls -n production \
  cert-manager.io/issuer-name-

# Method 3: Delete the secret (cert-manager will recreate it)
kubectl delete secret vault-api-tls -n production
# cert-manager detects the secret is gone, re-issues immediately
```

---

## Verify HTTPS is Working

```bash
# Test from outside the cluster
curl -vI https://api.vault.example.com/health

# Should show:
# * Connected to api.vault.example.com:443
# * SSL connection using TLSv1.3
# * Server certificate:
# *   subject: CN=api.vault.example.com
# *   start date: Jun  1 10:22:31 2026 GMT
# *   expire date: Aug 30 10:22:31 2026 GMT
# *   issuer: C=US, O=Let's Encrypt, CN=E5
# *   SSL certificate verify ok.
# HTTP/2 200

# Check the certificate expiry
echo | openssl s_client -connect api.vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -dates
# notAfter=Aug 30 10:22:31 2026 GMT
```

---

## Common Misunderstanding: "I need to open port 443 on the Load Balancer for cert issuance"

**The misunderstanding:** "The ACME challenge happens on port 443 — I need HTTPS open before I can get a certificate."

**The reality:** HTTP-01 challenges happen entirely over HTTP (port 80). Let's Encrypt checks your domain on HTTP, not HTTPS. This is intentional — you need to get a cert before you can serve HTTPS.

Port 443 can stay closed during initial certificate issuance. Open it (or your ingress handles it) after the cert is in the Secret.

In practice, nginx serves both port 80 and port 443. The cert-manager challenge uses port 80. Normal HTTPS traffic uses port 443. Both ports just need to be open in your Load Balancer security group.

→ Continue to: `06-dns01-and-wildcards.md`
