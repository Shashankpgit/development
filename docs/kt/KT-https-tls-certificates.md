# KT — HTTPS, TLS, and Certificates

## Part 1 — What is HTTP and what's wrong with it

When your browser talks to a server using HTTP, everything is sent as plain text. Every router, ISP, and device between you and the server can read the full conversation.

Example — a login request over HTTP:

```
POST /auth/login HTTP/1.1
Host: vaultpraja.duckdns.org

{"username": "alice", "password": "mysecret123"}
```

Anyone on the network path sees this exactly. Your ISP sees it. A coffee shop Wi-Fi operator sees it. Anyone running a packet sniffer on the same network sees it.

For a vault app storing passwords and private notes — this is unacceptable.

---

## Part 2 — What HTTPS does

HTTPS = HTTP + TLS (Transport Layer Security).

TLS wraps the HTTP conversation in an encrypted tunnel. The data that travels over the network looks like random bytes to anyone watching:

```
Before encryption (what you send):
POST /auth/login {"username": "alice", "password": "mysecret123"}

What travels on the network (encrypted):
x7Kp9mR2nQ8vL3wE5jF1aZ6cY4bX0sT...  ← meaningless without the key
```

Only the browser and your server can decrypt it. Nobody in between can.

---

## Part 3 — How does TLS work (the short version)

TLS uses a combination of asymmetric and symmetric encryption. You don't need to know the deep math, but understanding the handshake matters:

```
1. Browser connects to vaultpraja.duckdns.org:443

2. Server sends its CERTIFICATE
   (contains: domain name, public key, expiry, who signed it)

3. Browser checks:
   - Is this certificate valid for vaultpraja.duckdns.org?
   - Is it signed by a CA I trust?
   - Has it expired?

4. If all checks pass:
   Browser and server negotiate a shared secret key using the public key

5. All further communication is encrypted with that shared secret key
```

The certificate is the critical piece. It's what proves to the browser that the server is genuinely `vaultpraja.duckdns.org` and not someone pretending to be it.

---

## Part 4 — What is a Certificate Authority (CA)

A Certificate Authority is an organisation that browsers inherently trust to vouch for domain ownership.

Your browser comes pre-installed with a list of trusted CAs (you can see it in browser settings → certificates). Examples:
- DigiCert
- Comodo
- GlobalSign
- **Let's Encrypt** ← the free one we use

When a CA issues you a certificate, it digitally signs it. The browser sees that signature and says "I trust DigiCert / Let's Encrypt, and they have verified this server owns this domain."

**Without a CA signature:**
The browser shows a scary red warning — "Your connection is not private" — because anyone can generate a self-signed certificate and claim to be any domain.

---

## Part 5 — What is Let's Encrypt

Let's Encrypt is a free, automated, non-profit Certificate Authority. Before it existed (pre-2016), getting a TLS certificate cost $50–$300/year per domain. Let's Encrypt changed this by making certs free and automated.

It's now one of the most widely used CAs in the world. It's trusted by every major browser.

**Key facts:**
- Free forever
- Certificates valid for 90 days (auto-renewed by Certbot)
- Automated — no human involvement, no approval process
- Trusted by Chrome, Firefox, Safari, Edge

---

## Part 6 — How Let's Encrypt proves you own the domain (ACME protocol)

This is called the **ACME challenge**. Before Let's Encrypt will issue a certificate for `vaultpraja.duckdns.org`, it needs proof that you actually control that domain. Here's how:

```
Step 1 — You run Certbot on your server

Step 2 — Certbot contacts Let's Encrypt:
  "I want a certificate for vaultpraja.duckdns.org"

Step 3 — Let's Encrypt responds with a challenge:
  "Serve this random token at:
   http://vaultpraja.duckdns.org/.well-known/acme-challenge/RANDOM_TOKEN"

Step 4 — Certbot temporarily runs a small web server on port 80
  and serves the token at that URL

Step 5 — Let's Encrypt makes an HTTP request to that URL
  If the token matches → you control the domain → challenge passed

Step 6 — Let's Encrypt issues the certificate
  Certbot saves it to: /etc/letsencrypt/live/vaultpraja.duckdns.org/
```

Why does this prove ownership? Because only someone who controls the domain (and thus controls what the server at that IP responds with) can serve the correct token. If someone else tried to get a cert for your domain, they'd fail the challenge because they don't control your server.

---

## Part 7 — What files Certbot creates

After running Certbot, you get two critical files:

```
/etc/letsencrypt/live/vaultpraja.duckdns.org/
├── fullchain.pem   ← the certificate (public, share with browser)
└── privkey.pem     ← the private key (secret, never share)
```

**fullchain.pem** — Contains your certificate + the intermediate certificates that chain up to the Let's Encrypt root CA. Nginx serves this to browsers.

**privkey.pem** — The private key. Used by the server to decrypt the TLS session. If someone gets this file, they can impersonate your server. Never commit it to git, never share it.

These files get mounted into the nginx Docker container so nginx can use them to serve HTTPS.

---

## Part 8 — Why certs expire in 90 days

Let's Encrypt certificates last 90 days. This might seem short but it's intentional:

- **Shorter-lived certs = less damage if compromised.** If someone steals your private key, it's only valid for 90 days at most.
- **Forces automation.** You can't just get a cert and forget it. You need auto-renewal, which means your infrastructure stays healthy.
- **Industry is moving toward even shorter certs** — Google proposed 90-day max for all CAs.

Certbot sets up a **systemd timer** (like a cron job) that runs twice a day and renews any cert expiring within 30 days. You never need to think about it.

---

## Part 9 — What nginx does with the certificate

Currently nginx serves only HTTP. After certbot, nginx serves two ports:

**Port 80 (HTTP):** Only used to redirect to HTTPS
```
Browser → http://vaultpraja.duckdns.org
nginx responds: 301 Redirect → https://vaultpraja.duckdns.org
```

**Port 443 (HTTPS):** The real app
```
Browser → https://vaultpraja.duckdns.org (TLS handshake using cert)
nginx decrypts → routes to Kong / Keycloak / frontend internally
```

This pattern is called **TLS termination** — nginx handles the encryption/decryption at the edge. Everything inside Docker (Kong, API, Keycloak) communicates over plain HTTP on the internal Docker network, which is safe because it never leaves the server.

```
Internet
    │
    │  HTTPS (encrypted)
    ▼
  Nginx ──→ decrypts here (TLS termination)
    │
    │  HTTP (plain, but internal only — never leaves the server)
    ├──→ Kong → FastAPI
    ├──→ Keycloak
    └──→ Frontend (static files)
```

---

## Part 10 — Why Keycloak needs KC_PROXY: edge

When nginx decrypts HTTPS and forwards to Keycloak over plain HTTP, Keycloak sees an HTTP request. It doesn't know the original request was HTTPS.

So Keycloak builds URLs like:
```
http://vaultpraja.duckdns.org/realms/vault/...   ← wrong, http
```

But the browser is at `https://...`. These URLs won't work and the OAuth redirect breaks.

`KC_PROXY: edge` tells Keycloak:
> "You're behind a reverse proxy. Trust the X-Forwarded-Proto header that nginx adds."

nginx adds this header:
```
X-Forwarded-Proto: https
```

Keycloak reads it and builds:
```
https://vaultpraja.duckdns.org/realms/vault/...   ← correct
```

---

## Summary

| Concept | What it is |
|---|---|
| TLS | Protocol that encrypts the HTTP connection |
| Certificate | Proof of identity + public key, signed by a CA |
| CA (Certificate Authority) | Organisation browsers trust to verify domain ownership |
| Let's Encrypt | Free CA — issues certs via automated ACME challenge |
| Certbot | Tool that automates talking to Let's Encrypt |
| ACME challenge | Proves you own the domain by serving a token on port 80 |
| fullchain.pem | Your certificate — given to browsers |
| privkey.pem | Your private key — never share, never commit |
| TLS termination | nginx decrypts HTTPS, forwards plain HTTP internally |
| KC_PROXY: edge | Tells Keycloak to trust nginx's X-Forwarded-Proto header |
