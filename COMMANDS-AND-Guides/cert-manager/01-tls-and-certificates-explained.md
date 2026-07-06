# Cert-Manager & Let's Encrypt — 01: TLS and Certificates Explained

> **Last updated:** June 25, 2026
> **Covers:** TLS handshake step-by-step, what's inside a certificate, certificate chain, how nginx uses it

**20-minute read. This is the foundation everything else builds on.**

---

## The TLS Handshake — Step by Step

When your browser connects to `https://api.vault.example.com/api/auth`, this happens BEFORE any HTTP data is exchanged:

```
Browser                              Server (nginx)
  │                                      │
  │──── ClientHello ─────────────────────►│
  │    "I support TLS 1.3"               │
  │    "Here are my cipher suites"        │
  │    "Here's a random nonce (client)"  │
  │                                      │
  │◄─── ServerHello ─────────────────────│
  │    "Let's use TLS 1.3 + AES-256"     │
  │    "Here's a random nonce (server)"  │
  │                                      │
  │◄─── Certificate ─────────────────────│
  │    "Here's my certificate"           │
  │    (issued by Let's Encrypt,         │
  │     signed with Let's Encrypt's key) │
  │                                      │
  │    [Browser validates certificate]   │
  │    - Is it for this domain? ✓        │
  │    - Is it signed by a trusted CA? ✓ │
  │    - Is it expired? ✗ (not expired)  │
  │                                      │
  │──── Finished ──────────────────────►│
  │    [Key agreement complete]          │
  │                                      │
  ├════════ Encrypted channel ══════════╡
  │                                      │
  │══── GET /api/auth ═════════════════►│
  │◄═══ 200 OK { "token": "..." } ══════│
```

The entire handshake takes ~1-2 round trips. After that, all HTTP traffic is encrypted.

---

## What Is a Certificate?

A certificate is a structured text file (X.509 format). It contains:

```
Certificate
  ├── Subject: CN=api.vault.example.com
  │   (the domain this cert is for)
  │
  ├── Subject Alternative Names (SANs):
  │   DNS: api.vault.example.com
  │   DNS: vault.example.com
  │   (multiple domains a single cert covers)
  │
  ├── Issuer: Let's Encrypt R11
  │   (who signed this certificate)
  │
  ├── Validity:
  │   Not Before: 2026-06-01
  │   Not After:  2026-08-30
  │   (Let's Encrypt issues 90-day certs)
  │
  ├── Public Key: [2048-bit RSA or 256-bit ECDSA key]
  │   (used during the TLS handshake for key exchange)
  │
  └── Signature: [cryptographic signature by Let's Encrypt]
    (proves this cert was issued by Let's Encrypt)
```

A certificate file on disk looks like:

```
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
... (base64 encoded binary data) ...
-----END CERTIFICATE-----
```

This file is NOT secret. Anyone can read it. It's only valuable when paired with the private key.

---

## The Private Key — The Secret Half

The certificate contains a **public key** (shareable). The server holds the matching **private key** (secret).

```
Private key looks like:
-----BEGIN EC PRIVATE KEY-----
MHQCAQEEIONSsNxrpXR8XPgFphkzIAU7wFyzmvLEfT6QT25qvLK0oAoGCCqGSM49
... (never share this) ...
-----END EC PRIVATE KEY-----
```

The private key is:
- Generated once (when you request the certificate)
- NEVER sent to Let's Encrypt or anyone else
- Stored as a Kubernetes Secret by cert-manager
- Used by nginx to prove it owns the certificate

If an attacker gets your private key, they can impersonate your server. **Treat it like a password.**

In Kubernetes, cert-manager stores both files in a Secret:

```yaml
# What cert-manager creates (simplified)
apiVersion: v1
kind: Secret
metadata:
  name: vault-api-tls
  namespace: production
type: kubernetes.io/tls
data:
  tls.crt: <base64 encoded certificate + chain>  # public, shareable
  tls.key: <base64 encoded private key>           # secret, keep safe
```

---

## The Certificate Chain (Why Three Certificates?)

When your browser validates a cert, it doesn't just check the leaf cert. It checks the full chain:

```
Root CA Certificate
  "DigiSign Global Root G2"
  Validity: 2023-2038
  Trusted by: your OS (pre-installed)
    │
    │ signed by Root CA
    ▼
Intermediate CA Certificate
  "Let's Encrypt R11"  
  Validity: 2024-2027
    │
    │ signed by Intermediate CA
    ▼
Your Certificate (leaf cert)
  "api.vault.example.com"
  Validity: June 2026 - August 2026
```

Why the intermediate? Root CA private keys are extremely valuable — if they're ever compromised, millions of certificates become untrusted overnight. So Root CAs stay offline in air-gapped hardware. Intermediates are what sign day-to-day certificates.

When cert-manager stores your certificate, the `tls.crt` file contains BOTH your leaf cert AND the intermediate cert (called the "full chain"). This is what nginx needs to send to browsers.

---

## How nginx Uses the Certificate

```yaml
# In your Ingress resource:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault-api-ingress
spec:
  tls:
  - hosts:
    - api.vault.example.com
    secretName: vault-api-tls          # ← cert-manager puts the cert here
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

nginx ingress controller watches for Ingress resources. When it sees `spec.tls`, it:
1. Reads the Secret `vault-api-tls`
2. Loads the certificate and private key into memory
3. Configures nginx to use them for TLS termination on port 443
4. All HTTPS traffic to `api.vault.example.com` gets decrypted before forwarding to `vault-api:3000`

---

## The Real-World Request Flow

Let's trace a real request from start to finish:

```
User: POST https://api.vault.example.com/api/auth
      { "email": "shashank@example.com", "password": "secret" }
```

**Step 1: DNS Lookup**
```
Browser → DNS resolver
"What's the IP for api.vault.example.com?"
DNS → "It's 52.66.x.x" (your AWS Load Balancer IP)
```

**Step 2: TCP Connection**
```
Browser → 52.66.x.x:443 (TCP SYN)
Load Balancer accepts → TCP connection established
```

**Step 3: TLS Handshake**
```
Browser → nginx ingress: "I want TLS for api.vault.example.com"
nginx → Browser: "Here's the certificate for api.vault.example.com"
                  (cert was stored by cert-manager in vault-api-tls Secret)
Browser: validates cert chain → Let's Encrypt → DigiSign root
Browser: root is trusted by my OS → ✓
TLS session established with AES-256-GCM encryption
```

**Step 4: HTTP Request (now encrypted)**
```
Browser → nginx (encrypted):
  POST /api/auth HTTP/1.1
  Host: api.vault.example.com
  Content-Type: application/json
  {"email":"shashank@example.com","password":"secret"}
```

**Step 5: nginx Decrypts and Forwards**
```
nginx → vault-api pod (plain HTTP inside cluster):
  POST /api/auth HTTP/1.1
  Host: api.vault.example.com
  X-Forwarded-Proto: https
  X-Real-IP: <user's IP>
  {"email":"shashank@example.com","password":"secret"}
```

**Step 6: Response**
```
vault-api → nginx → Browser (encrypted):
  HTTP/1.1 200 OK
  {"token": "eyJhbGc..."}
```

The password "secret" was never visible outside the encrypted TLS tunnel. The user's IP is logged by nginx but not exposed to the app (unless via `X-Real-IP`).

---

## Certificate Formats You'll Encounter

| Format | Extension | What It Is |
|--------|-----------|------------|
| PEM | `.pem`, `.crt`, `.cer` | Base64 text format — what cert-manager stores |
| DER | `.der` | Binary format — same data, different encoding |
| PKCS12 | `.p12`, `.pfx` | Bundle: cert + key in one file (used by Java apps) |
| JKS | `.jks` | Java KeyStore — Java apps only |

cert-manager always outputs PEM format in Kubernetes Secrets. This works directly with nginx, Traefik, HAProxy, and most other tools.

---

## Common Misunderstanding: "Self-signed certificates are fine for production"

**The misunderstanding:** "I'll just generate a self-signed cert — it still encrypts the traffic, right?"

**The reality:** Self-signed certs encrypt traffic, but browsers show a scary warning because the cert isn't signed by a trusted CA. Users see:

```
⚠️  Your connection is not private
  Attackers might be trying to steal your information from 
  api.vault.example.com
  [Back to safety]  [Advanced]
```

This happens because your self-signed cert has no chain back to a trusted root CA. The browser has no way to know if YOU created it or if an attacker created it.

Self-signed certs are useful for:
- Internal development (not public-facing)
- Internal cluster communication (service-to-service)
- Testing pipelines

For anything users access directly: use Let's Encrypt.

→ Continue to: `02-lets-encrypt-and-acme.md`
