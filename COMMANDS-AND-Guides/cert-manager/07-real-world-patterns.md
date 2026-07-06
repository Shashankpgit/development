# Cert-Manager & Let's Encrypt — 07: Real-World Patterns

> **Last updated:** June 25, 2026
> **Covers:** Production patterns, GitOps, self-signed internal certs, monitoring, complete troubleshooting guide

**20-minute read. The patterns that appear in real production deployments.**

---

## Pattern 1: Helm Chart with TLS Baked In

Don't manage Ingress YAML manually — put TLS configuration in your Helm chart values.

```yaml
# helm/vault-api/values.yaml
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  host: api.vault.example.com
  tls:
    enabled: true
    secretName: vault-api-tls
```

```yaml
# helm/vault-api/templates/ingress.yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "vault-api.fullname" . }}
  namespace: {{ .Release.Namespace }}
  annotations:
    {{- toYaml .Values.ingress.annotations | nindent 4 }}
spec:
  ingressClassName: {{ .Values.ingress.ingressClassName }}
  {{- if .Values.ingress.tls.enabled }}
  tls:
  - hosts:
    - {{ .Values.ingress.host }}
    secretName: {{ .Values.ingress.tls.secretName }}
  {{- end }}
  rules:
  - host: {{ .Values.ingress.host }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ include "vault-api.fullname" . }}
            port:
              number: {{ .Values.service.port }}
{{- end }}
```

Now environment-specific values:

```yaml
# helm/vault-api/values.staging.yaml
ingress:
  host: api.staging.vault.example.com
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging  # staging issuer
  tls:
    secretName: vault-api-staging-tls

# helm/vault-api/values.production.yaml
ingress:
  host: api.vault.example.com
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod     # production issuer
  tls:
    secretName: vault-api-tls
```

---

## Pattern 2: GitOps with ArgoCD

In a GitOps setup, cert-manager manifests live in Git. ArgoCD applies them.

```yaml
# argocd/cert-manager-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
spec:
  project: infrastructure
  source:
    repoURL: https://charts.jetstack.io
    chart: cert-manager
    targetRevision: v1.16.3
    helm:
      values: |
        installCRDs: true
        replicaCount: 2
        prometheus:
          enabled: true
          servicemonitor:
            enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true    # important for CRDs
```

```yaml
# argocd/cluster-issuers-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluster-issuers
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/k8s-infra
    targetRevision: main
    path: cert-manager/issuers           # directory with ClusterIssuer YAMLs
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**GitOps secret handling:** Your ClusterIssuer references a Secret (ACME account key, Route53 credentials). These secrets should NOT be in Git. Two options:

```yaml
# Option A: External Secrets Operator
# Creates the k8s Secret from AWS Secrets Manager / Vault
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: route53-credentials
  namespace: cert-manager
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  target:
    name: route53-credentials
  data:
  - secretKey: secret-access-key
    remoteRef:
      key: prod/cert-manager/route53
      property: secretAccessKey
```

```yaml
# Option B: Sealed Secrets (encrypts the secret for Git storage)
# Install: https://github.com/bitnami-labs/sealed-secrets
kubectl create secret generic route53-credentials \
  --from-literal=secret-access-key=<value> --dry-run=client -o yaml \
  | kubeseal --controller-namespace sealed-secrets > route53-credentials-sealed.yaml
# The sealed YAML is safe to commit to Git
```

---

## Pattern 3: Internal PKI with Self-Signed Certificates

For internal cluster communication (service-to-service, not user-facing), you don't want Let's Encrypt. You want your own internal CA.

Use case: mutual TLS between microservices, internal webhooks, service mesh certificates.

```yaml
# Step 1: Create a self-signed root CA
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}

---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-internal-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: vault-internal-ca
  secretName: vault-internal-ca-tls
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
```

```yaml
# Step 2: Create a ClusterIssuer that uses your internal CA
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-internal-ca
spec:
  ca:
    secretName: vault-internal-ca-tls    # the CA cert+key created above
```

```yaml
# Step 3: Issue internal certificates from your CA
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-worker-internal-tls
  namespace: production
spec:
  secretName: vault-worker-internal-tls
  dnsNames:
  - vault-worker.production.svc.cluster.local
  - vault-worker.production.svc
  issuerRef:
    name: vault-internal-ca
    kind: ClusterIssuer
  duration: 720h     # 30 days (shorter for internal certs)
  renewBefore: 168h  # renew 7 days before expiry
```

These internal certs don't need Let's Encrypt. They're issued instantly, signed by your internal CA, and not trusted by browsers (that's fine — they're for internal use only).

---

## Pattern 4: Certificate for Multiple Environments

Use one ClusterIssuer but route different domains to different solvers:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: devops@vault.example.com
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    
    # Wildcard for vault.example.com → DNS-01 via Cloudflare
    - selector:
        dnsZones:
        - vault.example.com
      dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
    
    # Wildcard for vault.internal → DNS-01 via Route53 (private zone)
    - selector:
        dnsZones:
        - vault.internal
      dns01:
        route53:
          region: ap-south-1
          hostedZoneID: Z987654321
    
    # Everything else → HTTP-01
    - http01:
        ingress:
          ingressClassName: nginx
```

---

## Production Checklist

Before going live with cert-manager in production:

```
Pre-launch:
  □ cert-manager replicas ≥ 2
  □ PodDisruptionBudget enabled
  □ Resources/limits set
  □ Prometheus metrics enabled
  
ClusterIssuer:
  □ Staging issuer tested first (cert issued successfully)
  □ Production issuer configured
  □ Email is a real monitored address (Let's Encrypt sends expiry warnings)
  □ ACME account key backed up (kubectl get secret letsencrypt-prod-account-key)
  
Certificates:
  □ All production certificates in READY=True state
  □ cert expiry dates logged (kubectl get certs -A)
  □ Renewal tested (delete a staging cert Secret, verify it re-issues)
  
Monitoring:
  □ Alert: cert READY=False for >10 minutes
  □ Alert: cert expiry <7 days (cert-manager failed to renew)
  □ Alert: cert-manager pod not running
  □ Alert: ACME order failure rate (cert-manager metrics)
  
Security:
  □ ACME private key Secret accessible only to cert-manager
  □ DNS API credentials stored in Secret, not in ConfigMap
  □ Certificate Secrets accessible only to relevant namespaces
```

---

## Monitoring Cert-Manager

```yaml
# Prometheus alert rules
groups:
- name: cert-manager
  rules:
  
  # Certificate expiring soon (cert-manager failed to renew)
  - alert: CertificateExpiringSoon
    expr: |
      certmanager_certificate_expiration_timestamp_seconds - time() < 7 * 24 * 3600
    for: 1h
    labels:
      severity: critical
    annotations:
      summary: "Certificate {{ $labels.name }} expiring in <7 days"
      description: "Namespace: {{ $labels.namespace }}"

  # Certificate not ready
  - alert: CertificateNotReady
    expr: |
      certmanager_certificate_ready_status{condition="False"} == 1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Certificate {{ $labels.name }} is not ready"

  # High ACME error rate
  - alert: AcmeHighErrorRate
    expr: |
      rate(certmanager_http_acme_client_request_duration_seconds_count{status=~"4..|5.."}[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "cert-manager ACME requests failing"
```

---

## Full Troubleshooting Playbook

```bash
# ==========================================
# Level 1: Quick Status Check
# ==========================================

# Are all cert-manager pods running?
kubectl get pods -n cert-manager

# Are all certificates ready?
kubectl get certificates -A

# Any recent errors?
kubectl get events -A | grep cert-manager | grep -i error | tail -20


# ==========================================
# Level 2: Certificate Not Issuing
# ==========================================

# 1. Find the stuck certificate
kubectl get certificates -A | grep -v True

# 2. Describe it to see the condition
kubectl describe certificate <name> -n <namespace>

# 3. Find the Order
kubectl get orders -n <namespace>
kubectl describe order <order-name> -n <namespace>

# 4. Find the Challenge
kubectl get challenges -n <namespace>
kubectl describe challenge <challenge-name> -n <namespace>

# 5. Check cert-manager logs around the time of failure
kubectl logs -n cert-manager deploy/cert-manager --since=30m | grep -i error


# ==========================================
# Level 3: HTTP-01 Challenge Failing
# ==========================================

# Is the solver pod running?
kubectl get pods -n <namespace> | grep cm-acme-http-solver

# Is the temporary Ingress there?
kubectl get ingress -n <namespace> | grep cm-acme-http-solver

# Can you reach the challenge URL?
CHALLENGE_TOKEN=$(kubectl get challenge <name> -n <namespace> \
  -o jsonpath='{.spec.token}')
curl http://<your-domain>/.well-known/acme-challenge/${CHALLENGE_TOKEN}

# Expected: token.keyauth response
# If 404: nginx can't reach the solver pod
# If connection refused: port 80 is blocked


# ==========================================
# Level 4: DNS-01 Challenge Failing
# ==========================================

# Was the TXT record created?
dig TXT _acme-challenge.<your-domain>

# Was it created with the right value?
kubectl describe challenge <name> -n <namespace>
# Look for: "Presented=true" under status

# Check cert-manager logs for DNS API errors
kubectl logs -n cert-manager deploy/cert-manager | grep -i "route53\|cloudflare\|dns"


# ==========================================
# Level 5: Certificate Renewal Failing
# ==========================================

# Check renewal time
kubectl get certificate <name> -n <namespace> \
  -o jsonpath='{.status.renewalTime}'

# Manually trigger renewal
cmctl renew <name> -n <namespace>

# Check for rate limiting
kubectl logs -n cert-manager deploy/cert-manager | grep -i "rate limit"
# If hit: wait 1 week for Let's Encrypt production, or use staging to test
```

---

## Common Misunderstanding: "cert-manager is overkill for a small cluster"

**The misunderstanding:** "I only have 3 services. I'll just manage TLS manually with certbot."

**The reality:** cert-manager's value isn't in the initial setup — it's in the 6 months after, when you're not thinking about TLS at all. Without cert-manager:

```
6 months from now:
  - certbot cron job silently failed last month
  - Certificate expired on a Saturday at 3am
  - Users see "connection not secure" warnings
  - You get paged at 3am
  - It takes 30 minutes to fix because you forgot the certbot config
```

With cert-manager:
```
6 months from now:
  - You've thought about TLS zero times
  - All certificates renewed automatically
  - You're asleep at 3am
```

cert-manager is worth installing for even a single service. The one-time setup cost is ~30 minutes. The long-term maintenance cost is near zero.

→ Continue to: `README.md`
