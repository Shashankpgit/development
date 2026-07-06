# Cert-Manager & Let's Encrypt — 00: The Mental Model

> **Last updated:** June 25, 2026
> **Covers:** Why HTTPS, why Let's Encrypt, why cert-manager, how they fit together

**20-minute read. This file answers the WHY before any commands.**

---

## Start Here: What Problem Are We Solving?

Your API is running inside Kubernetes. Users hit it at `https://api.vault.example.com`.

That `https` in the URL involves three distinct problems:

```
Problem 1: Encryption
  Without TLS, anyone on the network can read the traffic
  (passwords, session tokens, user data — all visible as plaintext)

Problem 2: Identity
  How does the browser know it's talking to YOUR server
  and not an attacker who intercepted the connection?

Problem 3: Certificate Lifecycle
  TLS certificates expire (Let's Encrypt: 90 days).
  Who renews them? When? What if they expire on a weekend?
```

**TLS** solves problems 1 and 2.
**Let's Encrypt** makes TLS certificates free and automated.
**cert-manager** solves problem 3 — it runs inside Kubernetes and handles the entire lifecycle automatically.

---

## Part 1: Why TLS Exists

Before HTTPS, HTTP traffic looked like this:

```
User's browser → ISP router → internet backbone → your server
    ↑                ↑                 ↑
 can read         can read          can read
 everything      everything        everything
```

When someone logged into your app, their password traveled as plain text through dozens of machines they don't control.

TLS solves this by encrypting the connection end-to-end:

```
User's browser ──[encrypted tunnel]──────────────── your server
                   ISP can see:                 
                   "traffic to api.vault.example.com"
                   ISP CANNOT see:              
                   the actual content           
```

But encryption alone isn't enough. **The identity problem remains.**

---

## Part 2: The Identity Problem (Why Certificates Exist)

Imagine an attacker intercepts your traffic. They could:
1. Intercept your connection to `api.vault.example.com`
2. Pretend to be your server
3. Offer their own encrypted connection

You'd have encrypted traffic — but to the attacker's machine.

This is a **Man-in-the-Middle (MITM) attack**.

Certificates prevent this. A certificate is a **digitally signed proof** of identity:

```
Certificate says:
  "I am api.vault.example.com
   My public key is: [key]
   This is verified and signed by: Let's Encrypt"
```

The browser trusts Let's Encrypt (it's pre-installed in your OS and browser). So it trusts the certificate. If an attacker tries to present a fake certificate, they can't get it signed by Let's Encrypt — they don't control `api.vault.example.com`.

---

## Part 3: The Trust Chain

Certificates work in a chain of trust:

```
Root CA (built into your OS/browser)
  └── Intermediate CA (Let's Encrypt R11)
        └── Your certificate (api.vault.example.com)
```

Your OS comes pre-installed with ~150 trusted **Root Certificate Authorities** (CAs). These are companies like DigiCert, GlobalSign, and Let's Encrypt. When your browser sees a certificate, it traces the signature chain back to one of these trusted roots.

If the chain leads to a trusted root → connection is safe.
If the chain doesn't lead to a trusted root → "Your connection is not private" warning.

---

## Part 4: Why Let's Encrypt Changed Everything

Before Let's Encrypt (launched 2016), getting a TLS certificate required:
1. Paying $50-$300/year per domain
2. Manual verification process (email or phone calls)
3. Manually downloading and installing the certificate
4. Remembering to renew before expiry
5. Repeating this every 1-2 years

This was expensive, slow, and error-prone. The result: most websites on the internet ran on HTTP, not HTTPS.

**Let's Encrypt made TLS free and automated:**
- Free certificates for any domain you control
- Automated issuance via the ACME protocol
- 90-day certificates (short expiry forces automation)
- Trusted by all major browsers and operating systems

Today, 85%+ of web traffic is HTTPS — largely because of Let's Encrypt.

---

## Part 5: The ACME Protocol (How Let's Encrypt Issues Certificates)

Let's Encrypt needs to verify that YOU actually control the domain you're requesting a certificate for. This is the **challenge**.

```
You: "Please give me a certificate for api.vault.example.com"

Let's Encrypt: "Prove you control that domain. 
  I'll give you a random token.
  Put it at http://api.vault.example.com/.well-known/acme-challenge/<token>
  I'll check in 60 seconds."

You: [puts the token at that URL]

Let's Encrypt: [checks the URL, sees the token]
  "Confirmed. Here's your certificate."
```

This is the **HTTP-01 challenge**. There's also a **DNS-01 challenge** (for wildcard certs and private clusters) — more on this in file 02.

---

## Part 6: The Problem with Manual ACME in Kubernetes

You could run `certbot` (Let's Encrypt's CLI tool) manually on a VM. That's fine for a single server.

But Kubernetes changes everything:

```
Problems with manual cert management in Kubernetes:

1. Where does the cert live?
   In a Kubernetes Secret — but certbot doesn't know about Kubernetes

2. Multiple ingress controllers
   Which one serves the ACME challenge HTTP endpoint?

3. 90-day expiry
   Who runs certbot renew? A cron job? Where does it run?
   What if the pod dies during renewal?

4. Multiple namespaces
   Your API is in 'production', your frontend is in 'staging'
   How do you share or separate certs?

5. GitOps
   Your Helm charts define your Ingress. But the cert is managed
   by a cron job on a VM somewhere. These drift apart.
```

---

## Part 7: cert-manager — The Kubernetes-Native Solution

cert-manager runs as a controller inside your cluster. It watches Kubernetes resources and manages certificates the Kubernetes way.

```
cert-manager watches for:
  Ingress resources with   cert-manager.io/cluster-issuer: letsencrypt-prod
  Certificate resources    (you can also create these directly)

When it sees one, it:
  1. Talks to Let's Encrypt on your behalf
  2. Handles the challenge (creates a temporary pod/ingress)
  3. Receives the certificate
  4. Stores it in a Kubernetes Secret
  5. Monitors expiry — renews 30 days before it expires
  6. Repeats this forever, automatically
```

Your Ingress resource just references the Secret. The TLS termination happens at the ingress controller. You never think about certificate renewal again.

---

## The Complete Picture

Here's how ALL the pieces fit together when a user hits your API:

```
User's browser
    │
    │ HTTPS request to api.vault.example.com
    ▼
AWS Load Balancer (ALB / NLB)
    │
    │ forwards to
    ▼
nginx ingress controller (inside cluster)
    │
    │ TLS termination here
    │ Uses the certificate in Secret: vault-api-tls
    │ (cert-manager put this Secret here)
    │
    │ forwards decrypted HTTP to
    ▼
vault-api pod
    │
    ▼
Response flows back through the same path, encrypted
```

cert-manager's job is entirely about maintaining that Secret (`vault-api-tls`). It:
- Creates it (by completing the Let's Encrypt challenge)
- Keeps it valid (by renewing before expiry)
- Notifies you if something goes wrong (via Kubernetes events + conditions)

---

## Three Concepts, One Sentence Each

| Concept | What It Does |
|---------|-------------|
| TLS Certificate | Proves your identity and encrypts traffic |
| Let's Encrypt | Issues free certificates via automated challenges |
| cert-manager | Manages the certificate lifecycle inside Kubernetes |

---

## Common Misunderstanding: "cert-manager gives me free TLS"

**The misunderstanding:** "I just install cert-manager and get free HTTPS."

**The reality:** cert-manager is the automation layer. The certificate itself comes from Let's Encrypt (or another CA you configure). cert-manager:
- Talks to Let's Encrypt for you
- Handles the domain validation challenge
- Stores the certificate as a Kubernetes Secret
- Renews it before expiry

Without Let's Encrypt (or another configured Issuer), cert-manager does nothing.

The real power: cert-manager + Let's Encrypt together mean you configure TLS ONCE and forget about it. That's the goal.

→ Continue to: `01-tls-and-certificates-explained.md`
