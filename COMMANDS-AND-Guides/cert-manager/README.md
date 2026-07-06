# cert-manager & Let's Encrypt Guide

> **Last updated:** June 25, 2026
> **Level:** DevOps Engineer (Beginner to Production-Ready)
> **Goal:** Understand TLS end-to-end and run cert-manager confidently in production

---

## What This Guide Covers

Full-stack TLS automation for Kubernetes — from first principles (why HTTPS exists) to production patterns (GitOps, wildcard certs, monitoring).

**The real-world problem this guide solves:**
> A user hits `https://api.vault.example.com/api/auth`. How does the "S" in HTTPS actually work? Who issues the certificate, who renews it, and what happens when it expires? This guide answers all of that.

---

## Reading Order

Read these in order — each file builds on the previous.

| File | What You Learn | Time |
|------|---------------|------|
| [00-mental-model.md](00-mental-model.md) | Why TLS, Why Let's Encrypt, Why cert-manager | 20 min |
| [01-tls-and-certificates-explained.md](01-tls-and-certificates-explained.md) | TLS handshake step-by-step, certificate anatomy | 20 min |
| [02-lets-encrypt-and-acme.md](02-lets-encrypt-and-acme.md) | ACME protocol, HTTP-01 vs DNS-01 challenges | 20 min |
| [03-cert-manager-architecture.md](03-cert-manager-architecture.md) | CRDs, internal flow: annotation → Secret | 20 min |
| [04-installation.md](04-installation.md) | Install cert-manager, create ClusterIssuer | 20 min |
| [05-http01-in-practice.md](05-http01-in-practice.md) | End-to-end nginx + cert-manager + Let's Encrypt | 20 min |
| [06-dns01-and-wildcards.md](06-dns01-and-wildcards.md) | Route53/Cloudflare, wildcard certs | 20 min |
| [07-real-world-patterns.md](07-real-world-patterns.md) | GitOps, internal PKI, monitoring, full troubleshooting | 20 min |

---

## The 3-Sentence Summary

**TLS certificates** prove your server is who it says it is and encrypt traffic between your users and your cluster. **Let's Encrypt** issues these certificates for free using the ACME protocol — it challenges you to prove you control the domain, then signs the cert. **cert-manager** automates this inside Kubernetes: it watches your Ingress resources, runs the ACME challenge, stores the certificate as a Secret, and renews it before it expires — you never think about certificates again.

---

## How Everything Connects

```
User
  │  HTTPS request
  ▼
AWS Load Balancer
  │
  ▼
nginx ingress controller
  │  ← reads TLS cert from Secret (cert-manager put it here)
  │  terminates TLS here
  ▼
Your Pod (plain HTTP inside cluster)
```

```
Ingress YAML with annotation
cert-manager.io/cluster-issuer: letsencrypt-prod
  │
  ▼ cert-manager sees this
Certificate resource created
  │
  ▼
CertificateRequest → Order → Challenge
  │
  ▼
Let's Encrypt validates domain ownership
(HTTP-01: serves file at /.well-known/acme-challenge/token)
(DNS-01: creates TXT record _acme-challenge.domain)
  │
  ▼
Certificate issued → stored in Secret vault-api-tls
  │
  ▼
nginx reloads → HTTPS works ✓
  │
  ▼ (30 days before expiry)
cert-manager auto-renews → repeat from Challenge step
```

---

## Quick Command Reference

```bash
# Installation
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true --version v1.16.3

# Check status
kubectl get pods -n cert-manager
kubectl get clusterissuer
kubectl get certificates -A

# Debug a stuck cert
kubectl describe certificate <name> -n <namespace>
kubectl get orders -n <namespace>
kubectl get challenges -n <namespace>

# Force renewal
cmctl renew <cert-name> -n <namespace>
# or: kubectl delete secret <tls-secret> -n <namespace>

# Verify TLS from outside
curl -vI https://api.vault.example.com
echo | openssl s_client -connect api.vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -dates
```

---

## Challenge Type Quick Pick

```
Public cluster, specific subdomains?
  → HTTP-01 (simpler, no DNS creds needed)

Wildcard cert (*.vault.example.com)?
  → DNS-01 (required — HTTP-01 can't do wildcards)

Private cluster (no public HTTP)?
  → DNS-01 (Let's Encrypt validates via DNS, not HTTP)

Internal service-to-service TLS?
  → Internal CA (self-signed ClusterIssuer, not Let's Encrypt)
```

---

## Common Errors Quick Fix

| Error | Cause | Fix |
|-------|-------|-----|
| `DNS problem: NXDOMAIN` | DNS not pointing to cluster | Create A/CNAME record for the domain |
| `connection refused on port 80` | Port 80 blocked | Open port 80 in security group |
| `too many certificates` | Hit rate limit (50/week) | Wait 7 days or use staging |
| `Certificate READY=False` | Challenge failing | See 07-real-world-patterns.md troubleshooting |
| Browser warning on staging cert | Expected — staging CA not trusted | Switch to production issuer |
| `Failed to query Route53` | IAM permissions missing | Check IAM policy has route53 permissions |

---

## References

- cert-manager docs: https://cert-manager.io/docs/
- Let's Encrypt docs: https://letsencrypt.org/docs/
- ACME protocol: RFC 8555
- cert-manager GitHub: https://github.com/cert-manager/cert-manager
- Supported DNS providers: https://cert-manager.io/docs/configuration/acme/dns01/
- cert-manager Helm chart: https://artifacthub.io/packages/helm/cert-manager/cert-manager

---

## Data Freshness

- cert-manager version covered: **v1.16.3** (latest stable as of June 2026)
- Let's Encrypt API: **ACME v2** (acme-v02.api.letsencrypt.org)
- Rate limits: verified against Let's Encrypt documentation June 2026
- AWS IRSA: works with EKS 1.14+ (all current EKS versions)
- Kubernetes API: v1.26+ (CRD APIs used are stable)
