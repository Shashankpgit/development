# Cert-Manager & Let's Encrypt — 02: Let's Encrypt and the ACME Protocol

> **Last updated:** June 25, 2026
> **Covers:** How ACME works, HTTP-01 vs DNS-01 challenges, rate limits, when to use which

**20-minute read. This is the mechanism behind automatic certificate issuance.**

---

## What Is ACME?

**ACME** = Automatic Certificate Management Environment. It's a protocol (RFC 8555) that automates the process of:
1. Proving you control a domain
2. Requesting a certificate for that domain
3. Installing and renewing it

Before ACME, you'd fill out a form, wait for a human to verify ownership, receive a certificate via email, and install it manually. ACME reduced this to a fully automated API interaction measured in seconds.

Let's Encrypt uses ACME. cert-manager implements the ACME protocol on your behalf.

---

## The ACME Flow (Full Detail)

```
cert-manager (your cluster)           Let's Encrypt ACME server
      │                                         │
      │── POST /acme/new-order ────────────────►│
      │   "I want a cert for api.vault.io"      │
      │                                         │
      │◄── 201 Created ─────────────────────────│
      │   "Prove you own api.vault.io"          │
      │   Challenge token: abc123               │
      │   Challenge types available:            │
      │     - http-01 (HTTP endpoint check)     │
      │     - dns-01 (DNS TXT record check)     │
      │                                         │
      │  [cert-manager picks http-01]           │
      │  [creates temporary Ingress route]      │
      │                                         │
      │── POST /acme/challenge/http-01 ────────►│
      │   "I'm ready, please check"             │
      │                                         │
Let's Encrypt checks:                           │
  GET http://api.vault.io/.well-known/          │
        acme-challenge/abc123                   │
  Gets: abc123.keyauth-token                    │
      │                                         │
      │◄── 200 Challenge valid ─────────────────│
      │                                         │
      │── POST /acme/finalize ─────────────────►│
      │   [sends CSR: certificate signing req]  │
      │                                         │
      │◄── 200 Certificate issued ──────────────│
      │   [downloads certificate]               │
      │                                         │
      │  [stores cert in Kubernetes Secret]     │
      │  [deletes temporary Ingress route]      │
```

From start to finish: ~30-60 seconds in normal conditions.

---

## HTTP-01 Challenge — Detailed

The HTTP-01 challenge proves domain ownership by serving a specific file over HTTP.

**What cert-manager does:**

```
1. Let's Encrypt gives cert-manager a token: "abc123xyz"
   and a key authorization: "abc123xyz.keyauth..."

2. cert-manager creates:
   - A temporary Service pointing to an ACME challenge solver pod
   - A temporary Ingress rule:
     http://api.vault.io/.well-known/acme-challenge/abc123xyz
     → solver pod
   
3. The solver pod serves the key authorization at that URL

4. Let's Encrypt's servers (from multiple geographic locations) 
   make HTTP requests to that URL

5. If they get the correct response → challenge passes

6. cert-manager removes the temporary Ingress + Service
   and stores the certificate in the Secret
```

**Real resources cert-manager creates during HTTP-01:**

```yaml
# Temporary Ingress (cert-manager creates this automatically)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cm-acme-http-solver-xkj2f    # random name
  namespace: production
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: api.vault.example.com
    http:
      paths:
      - path: /.well-known/acme-challenge/abc123xyz
        pathType: Exact
        backend:
          service:
            name: cm-acme-http-solver-xkj2f
            port:
              number: 8089
```

This Ingress lives for ~30-60 seconds, then cert-manager deletes it.

**HTTP-01 requirements:**
- Your domain must be publicly accessible on port 80 (HTTP)
- Your ingress controller must be running and reachable
- DNS must already point to your cluster
- Does NOT work for wildcard certificates (*.vault.example.com)
- Does NOT work for private clusters (no public internet access)

---

## DNS-01 Challenge — Detailed

The DNS-01 challenge proves domain ownership by creating a DNS TXT record.

**What happens:**

```
1. Let's Encrypt gives cert-manager a token: "abc123xyz"

2. cert-manager calls your DNS provider API (Route53, Cloudflare, etc.)
   Creates TXT record:
   _acme-challenge.api.vault.example.com → "abc123xyz-hash"

3. Let's Encrypt looks up that DNS TXT record
   (from multiple DNS resolvers globally)

4. If the TXT record exists with correct value → challenge passes

5. cert-manager deletes the TXT record
   Stores the certificate in the Secret
```

**Example: cert-manager calls Route53**

```
cert-manager → AWS Route53 API
  PUT /2013-04-01/hostedzone/Z123456/rrset
  {
    "Name": "_acme-challenge.api.vault.example.com",
    "Type": "TXT",
    "TTL": 120,
    "Value": "\"abc123xyz-hash\""
  }
```

**DNS-01 requirements:**
- Your DNS provider must have an API
- cert-manager must have credentials for that API
- DNS changes can take 30-120 seconds to propagate
- DOES work for wildcard certificates
- DOES work for private clusters (no public HTTP access needed)

---

## HTTP-01 vs DNS-01 — When to Use Which

| Requirement | HTTP-01 | DNS-01 |
|-------------|---------|--------|
| Wildcard cert (`*.vault.io`) | ✗ Not possible | ✓ Required |
| Private cluster (no public access) | ✗ Not possible | ✓ Required |
| Single domain cert | ✓ Easiest | ✓ Also works |
| No DNS API access | ✓ Use this | ✗ Not possible |
| Multiple subdomains | ✓ One cert each | ✓ One wildcard cert |
| Fastest setup | ✓ (no API creds needed) | Slower (needs DNS creds) |

**Rule of thumb:**
- Public cluster, specific subdomains → HTTP-01 (simpler)
- Wildcard cert needed, or private cluster → DNS-01

---

## Wildcard Certificates

A wildcard cert (`*.vault.example.com`) covers ALL subdomains:
- `api.vault.example.com` ✓
- `app.vault.example.com` ✓
- `staging.vault.example.com` ✓
- `anything.vault.example.com` ✓

But NOT:
- `vault.example.com` (the root domain — needs a separate cert or SAN)
- `api.staging.vault.example.com` (two levels deep — needs another wildcard)

**Wildcard certs require DNS-01 challenge** — Let's Encrypt policy, no exceptions.

Why? HTTP-01 can't prove you control ALL subdomains. DNS-01 proves you control the zone, which implicitly covers all subdomains.

---

## Let's Encrypt Rate Limits

Let's Encrypt is a public service — they rate limit to prevent abuse.

| Limit | Value | Notes |
|-------|-------|-------|
| Certificates per Registered Domain | 50/week | `vault.example.com` + all subdomains count as one registered domain |
| Duplicate certificates | 5/week | Same domain, same SANs |
| Failed validations | 5/hour per account, per hostname | Failed HTTP-01 or DNS-01 |
| New orders | 300/3 hours | Per account |

**Most important to know:**
- 50 certificates per registered domain per week
- If you're testing and burn through this, you're locked out for a week
- **Always use the Let's Encrypt STAGING environment for testing**

---

## Staging vs Production Let's Encrypt

Let's Encrypt has two environments:

```
Staging:    https://acme-staging-v02.api.letsencrypt.org/directory
Production: https://acme-v02.api.letsencrypt.org/directory
```

**Staging:**
- Unlimited certificates (for testing)
- Certificates are NOT trusted by browsers (issued by "Fake LE Root X1")
- Use this to test your cert-manager setup
- You'll see a browser warning — that's expected

**Production:**
- Rate limited (50 certs/registered domain/week)
- Certificates are trusted by all browsers
- Use this for real services

**The workflow:**
1. Set up cert-manager with staging issuer first
2. Verify the challenge works (cert is issued, even if not trusted)
3. Switch to production issuer
4. Delete the staging secret → cert-manager auto-creates a real cert

---

## What Happens at Renewal?

cert-manager renews 30 days before expiry:

```
Let's Encrypt cert lifetime: 90 days
cert-manager renewal window: 30 days before expiry
Effective cert rotation: every 60 days

Timeline:
Day 0:   cert issued (valid 90 days)
Day 60:  cert-manager starts renewal (30 days before day 90)
Day 65:  renewal completes (new cert valid another 90 days)
Day 90:  old cert expires (but you're already on new cert)
```

Renewal is completely automatic. cert-manager:
1. Notices the cert is within 30 days of expiry
2. Re-runs the full ACME flow (new challenge, new cert)
3. Updates the Kubernetes Secret with the new cert
4. nginx ingress controller detects the Secret changed, hot-reloads the cert

No downtime. No manual action. The cert renews itself.

---

## Common Misunderstanding: "cert-manager contacts Let's Encrypt from inside the cluster"

**For HTTP-01:** Let's Encrypt contacts your cluster from the outside (to verify the challenge endpoint). Your cluster must be publicly reachable on port 80.

```
Let's Encrypt servers → internet → your Load Balancer:80 → nginx:80 
  → acme-challenge solver pod
```

**For DNS-01:** cert-manager contacts the DNS provider API. Let's Encrypt contacts DNS servers. Your cluster does NOT need to be publicly reachable.

```
cert-manager → Route53 API (creates TXT record)
Let's Encrypt → DNS resolvers → sees TXT record
```

This is why DNS-01 is the only option for private/air-gapped clusters.

→ Continue to: `03-cert-manager-architecture.md`
