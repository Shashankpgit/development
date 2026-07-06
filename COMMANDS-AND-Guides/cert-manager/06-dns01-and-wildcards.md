# Cert-Manager & Let's Encrypt — 06: DNS-01 and Wildcard Certificates

> **Last updated:** June 25, 2026
> **Covers:** DNS-01 challenge with Route53 and Cloudflare, wildcard certs, private clusters

**20-minute read. Wildcard certs and private clusters both require DNS-01.**

---

## When You Need DNS-01

| Scenario | Why HTTP-01 Fails | Solution |
|----------|------------------|----------|
| `*.vault.example.com` wildcard | HTTP-01 can't prove control of all subdomains | DNS-01 required |
| Private cluster (no public internet) | Let's Encrypt can't reach port 80 | DNS-01 required |
| IP-blocked environment | ISP/firewall blocks inbound HTTP | DNS-01 required |
| Multiple ingress controllers | Ambiguous which handles the challenge | DNS-01 cleaner |

---

## DNS-01 with AWS Route53

### Step 1: Create IAM Policy for DNS Changes

cert-manager needs permission to create and delete DNS TXT records in Route53.

```json
// iam-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/<YOUR_HOSTED_ZONE_ID>"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    }
  ]
}
```

```bash
# Create the IAM policy
aws iam create-policy \
  --policy-name cert-manager-route53 \
  --policy-document file://iam-policy.json

# Note the policy ARN (you'll need it)
```

### Step 2: Option A — IAM Role for Service Account (IRSA) — Recommended for EKS

IRSA is the AWS-native way to give Kubernetes pods IAM permissions without storing credentials.

```bash
# Get your cluster's OIDC provider URL
aws eks describe-cluster --name vault-cluster \
  --query "cluster.identity.oidc.issuer" --output text
# Output: https://oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE123

# Create IAM Role with trust policy for cert-manager
aws iam create-role \
  --role-name cert-manager-route53 \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE123"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE123:sub": 
            "system:serviceaccount:cert-manager:cert-manager"
        }
      }
    }]
  }'

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name cert-manager-route53 \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/cert-manager-route53
```

```yaml
# Annotate the cert-manager ServiceAccount with the IAM Role ARN
# Add to helm values:
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/cert-manager-route53
```

### Step 2: Option B — Access Key (Simpler, less secure)

```bash
# Create an IAM user
aws iam create-user --user-name cert-manager-route53
aws iam attach-user-policy \
  --user-name cert-manager-route53 \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/cert-manager-route53
aws iam create-access-key --user-name cert-manager-route53
# Note the AccessKeyId and SecretAccessKey
```

```bash
# Store credentials as Kubernetes Secret
kubectl create secret generic route53-credentials \
  --from-literal=secret-access-key=<YOUR_SECRET_KEY> \
  -n cert-manager
```

### Step 3: ClusterIssuer with DNS-01 Route53

```yaml
# cluster-issuer-dns01-route53.yaml
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
    - dns01:
        route53:
          region: ap-south-1
          hostedZoneID: Z123456789ABCDEF   # your Route53 hosted zone ID
          
          # Option A: IRSA (no credentials needed in YAML)
          # Just set the serviceAccount annotation in helm values
          
          # Option B: Access Key credentials
          accessKeyIDSecretRef:
            name: route53-credentials
            key: access-key-id
          secretAccessKeySecretRef:
            name: route53-credentials
            key: secret-access-key
```

---

## DNS-01 with Cloudflare

Cloudflare is often easier to set up than Route53 — it uses a simple API token.

### Step 1: Create Cloudflare API Token

```
Cloudflare Dashboard → Profile → API Tokens → Create Token
Template: Edit zone DNS
Zone Resources: Include → Specific zone → vault.example.com
```

```bash
# Store the token as a Secret
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=<YOUR_CLOUDFLARE_API_TOKEN> \
  -n cert-manager
```

### Step 2: ClusterIssuer with Cloudflare

```yaml
# cluster-issuer-dns01-cloudflare.yaml
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
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
```

That's it. Cloudflare setup is three steps vs Route53's many steps.

---

## Wildcard Certificate Setup

A wildcard cert for `*.vault.example.com` covers all subdomains.

```yaml
# wildcard-cert.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-wildcard-tls
  namespace: production
spec:
  secretName: vault-wildcard-tls
  dnsNames:
  - "*.vault.example.com"           # wildcard — all subdomains
  - "vault.example.com"             # also the root domain (separate SAN)
  issuerRef:
    name: letsencrypt-prod           # must be a DNS-01 capable issuer
    kind: ClusterIssuer
```

```bash
kubectl apply -f wildcard-cert.yaml
kubectl get certificate vault-wildcard-tls -n production -w
```

### Using the Wildcard in Ingress Resources

```yaml
# api-ingress.yaml — api.vault.example.com (covered by wildcard)
spec:
  tls:
  - hosts:
    - api.vault.example.com
    secretName: vault-wildcard-tls    # ← reference the wildcard Secret
  rules:
  - host: api.vault.example.com
    ...

# frontend-ingress.yaml — app.vault.example.com (also covered)
spec:
  tls:
  - hosts:
    - app.vault.example.com
    secretName: vault-wildcard-tls    # ← same Secret
  rules:
  - host: app.vault.example.com
    ...
```

All subdomains share ONE certificate in ONE Secret. You add a new service by adding a new Ingress — no new certificate needed.

---

## Mixed Solvers: HTTP-01 for Most, DNS-01 for Wildcards

You can configure one ClusterIssuer with multiple solvers:

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
    
    # DNS-01 for wildcard certs (and vault.example.com specifically)
    - selector:
        dnsZones:
        - "vault.example.com"    # use DNS-01 for this zone
      dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
    
    # HTTP-01 for everything else (other domains)
    - http01:
        ingress:
          ingressClassName: nginx
```

cert-manager picks the solver based on the domain being requested.

---

## Private Cluster Setup (No Public Access)

Your cluster is in a private VPC. Let's Encrypt can't reach port 80. DNS-01 is the only option.

The setup is identical to the DNS-01 examples above. The key difference: cert-manager makes OUTBOUND requests to the DNS API (Route53/Cloudflare). Your cluster doesn't need inbound access. Let's Encrypt validates via DNS lookups — not HTTP.

```
Private cluster → (outbound) → Route53 API
                                     ↓
Let's Encrypt → DNS resolvers → sees TXT record
```

Your security group: outbound 443 to Route53/Cloudflare APIs. No inbound port 80 required.

---

## DNS Propagation and Wait Times

DNS changes take time to propagate. cert-manager handles this automatically, but you can configure it:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
spec:
  acme:
    solvers:
    - dns01:
        route53:
          region: ap-south-1
        # Wait for DNS propagation before notifying Let's Encrypt
        # Default: 10 seconds — may not be enough for all DNS providers
        cnameStrategy: Follow
```

For Route53, changes typically propagate in 10-60 seconds. For some providers, it can take up to 120 seconds. If you see intermittent challenge failures, increase the wait time by using the Route53's TTL and cert-manager's built-in retry logic handles this automatically.

---

## Troubleshooting DNS-01

### Challenge fails with "DNS record not found"

```bash
# Check if the TXT record was created
dig TXT _acme-challenge.api.vault.example.com

# Should show something like:
# _acme-challenge.api.vault.example.com. 120 IN TXT "abc123xyz-hash"

# If not found, check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager | grep -i dns
```

### "Failed to query Route53"
```bash
# Verify IAM permissions
kubectl exec -n cert-manager deploy/cert-manager -- \
  env | grep AWS    # check if env vars are set (for access key method)

# For IRSA, verify the annotation on the ServiceAccount
kubectl get serviceaccount cert-manager -n cert-manager -o yaml | grep annotations -A5
```

### DNS-01 works in staging but fails in production

Most likely a rate limit issue or a DNS propagation timing difference between staging and production Let's Encrypt servers. Check:

```bash
kubectl describe challenge -n production
# Look at the Events section for the specific error
```

---

## Common Misunderstanding: "Wildcard certs are more secure than specific certs"

**The misunderstanding:** "A wildcard cert `*.vault.example.com` is better than per-subdomain certs."

**The reality:** Wildcard certs are LESS secure in one important way:

If the private key for `*.vault.example.com` is compromised, ALL subdomains are at risk — including services you might not control directly. An attacker with the private key can impersonate any subdomain.

With per-domain certs:
- Compromise of `api.vault.example.com` cert → only affects the API
- Other services are unaffected

**When wildcards are practical:**
- You manage many subdomains and updating certs is operationally complex
- You're already securing the private key with Kubernetes RBAC
- The operational simplicity outweighs the slightly broader blast radius

**When per-domain is better:**
- Services managed by different teams
- External-facing services with higher security requirements
- You have few subdomains

In practice: wildcards are fine if your Kubernetes RBAC limits who can access the Secret.

→ Continue to: `07-real-world-patterns.md`
