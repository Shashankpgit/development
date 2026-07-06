# SOPS — 00: The Mental Model

> **Last updated:** July 3, 2026
> **Covers:** The secrets-in-git problem, how SOPS solves it, what encrypted files look like, when to use SOPS vs alternatives

**20-minute read. This file answers WHY SOPS exists before any commands.**

---

## The Core Problem: Secrets and Version Control

Every application needs secrets:

```
Database URL:       postgresql://admin:superSecret@db.internal:5432/vault
JWT Secret:         very-long-random-string-here
Stripe API Key:     sk_live_abcdef123456789
SendGrid API Key:   SG.xxxxxxxxxxxxxxxxxxx
AWS Access Key:     AKIAIOSFODNN7EXAMPLE
```

And every application uses configuration files that need to live in git:

```yaml
# config/production.yaml
database:
  host: db.internal
  port: 5432
  user: admin
  password: ???     # ← What goes here?

jwt:
  secret: ???       # ← And here?

stripe:
  api_key: ???      # ← And here?
```

This is the secrets management problem. You have three bad options and one good one:

---

## The Three Bad Approaches

### Bad Approach 1: Commit secrets to git (plaintext)

```yaml
# ❌ TERRIBLE — but people do this
database:
  password: superSecret
jwt:
  secret: very-long-random-string
stripe:
  api_key: sk_live_abcdef123456789
```

**Why it's bad:**
- Everyone with repo access sees all secrets
- Secrets in git history forever (even if you delete the file, `git log` shows them)
- One compromised developer account = all secrets exposed
- GitHub/GitLab can scan and expose them accidentally
- Third-party integrations (CI, code analysis) can read them

### Bad Approach 2: Don't version control secrets at all

Keep secrets on a shared drive, in Slack, in someone's notes.

**Why it's bad:**
- Secrets drift from what's actually deployed
- "Who has the production database password?" — nobody knows
- Onboarding new developer: "Ask Shashank, he has the secrets"
- No audit trail — who changed the API key and when?
- Disaster recovery: prod server dies, all secrets are on that server

### Bad Approach 3: Environment variables only, managed externally

Store secrets in AWS Secrets Manager, Vault, etc. Reference them as env vars in code.

**Why this is incomplete (not bad, just insufficient):**
- The secret NAMES and STRUCTURE aren't versioned
- What secrets does this service need? → read the code or ask someone
- Different environments have different secrets → how are they organized?
- You still need a way to document "these are the secrets this service uses"

---

## The SOPS Approach: Encrypted Files in Git

SOPS (Secrets OPerationS) by Mozilla solves this by encrypting secret files so they CAN be committed to git safely.

```yaml
# ✅ GOOD — committed to git, safe because it's encrypted
database:
    host: ENC[AES256_GCM,data:abc123,...]
    port: ENC[AES256_GCM,data:xyz789,...]
    user: ENC[AES256_GCM,data:def456,...]
    password: ENC[AES256_GCM,data:ghi012,...]
jwt:
    secret: ENC[AES256_GCM,data:jkl345,...]
stripe:
    api_key: ENC[AES256_GCM,data:mno678,...]
sops:
    kms: [...]
    age: [...]
    lastmodified: "2026-07-03T10:22:31Z"
    mac: ENC[AES256_GCM,data:pqr901,...]
    version: 3.9.0
```

**The key insight:** The encrypted file is versioned in git. The encryption KEY lives separately (in AWS KMS, or as a file on your machine). Anyone with the key can decrypt. Anyone without it sees only encrypted data.

---

## What SOPS Actually Encrypts

SOPS is smart about what it encrypts. It encrypts **VALUES, not KEYS**.

```yaml
# Before encryption (your secret file)
database:
  host: db.production.internal
  port: 5432
  password: superSecret

# After SOPS encryption
database:
  host: ENC[AES256_GCM,data:Zm9v...]
  port: ENC[AES256_GCM,data:NTQz...]
  password: ENC[AES256_GCM,data:c3Vw...]
```

Why this matters: **You can read the structure** (database, host, port, password) without decrypting. In a PR review, you can see that someone added a new key `redis.password` without seeing the actual password value. The diff is reviewable.

Compare that to a binary-encrypted file — you'd see `Binary file differs. Cannot show diff.`

---

## How SOPS Encryption Works

SOPS uses a two-layer encryption system:

```
Layer 1: Data Encryption Key (DEK)
  - A random AES-256 key generated per file
  - This key encrypts the actual secret values

Layer 2: Key Encryption Key (KEK)
  - Your AWS KMS key, age key, or PGP key
  - This key encrypts the DEK
  - The encrypted DEK is stored in the SOPS metadata at the bottom of the file

To decrypt:
  1. SOPS reads the encrypted DEK from the file metadata
  2. Uses your AWS KMS / age key to decrypt the DEK
  3. Uses the decrypted DEK to decrypt all the values
```

This architecture means:
- You can have MULTIPLE keys that can decrypt the same file (developer 1's key + developer 2's key + CI/CD key all work)
- Rotating who has access means re-encrypting the DEK (fast) — not re-encrypting all values (slow)

---

## The Encryption Backends

SOPS supports multiple backends for the Key Encryption Key:

```
age             Simple, modern, fast. A single .txt file is your key.
                Best for: personal use, small teams, simple setups.

AWS KMS         AWS Key Management Service. IAM controls who can decrypt.
                Best for: AWS-centric organizations, production systems.

GCP KMS         Google Cloud KMS. IAM controls access.
                Best for: GCP-centric organizations.

Azure Key Vault Microsoft Azure. RBAC controls access.
                Best for: Azure-centric organizations.

HashiCorp Vault For orgs already using Vault. Vault transit engine.
                Best for: multi-cloud orgs with Vault already deployed.

PGP/GPG         Legacy. Being replaced by age.
                Best for: teams with existing GPG infrastructure.
```

You can use MULTIPLE backends for the same file:
```yaml
# This file can be decrypted by: age key OR AWS KMS
sops:
  age:
  - recipient: age1abc...  # dev laptop key
  kms:
  - arn: arn:aws:kms:...   # CI/CD key
```

---

## The Daily Developer Workflow

```bash
# First time setup (one time):
# macOS:
brew install sops age

# Linux (Ubuntu/Debian x86_64):
curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops_3.9.0_amd64.deb
sudo dpkg -i sops_3.9.0_amd64.deb && rm sops_3.9.0_amd64.deb
sudo apt install age   # Ubuntu 22.04+, or download binary for older versions

# Linux (Amazon Linux 2023 / RHEL x86_64):
curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops-3.9.0-1.x86_64.rpm
sudo rpm -ivh sops-3.9.0-1.x86_64.rpm && rm sops-3.9.0-1.x86_64.rpm
# age: download binary from github.com/FiloSottile/age/releases

age-keygen -o ~/.config/sops/age/keys.txt

# Create an encrypted secrets file:
sops secrets/production.yaml

# → opens your editor (vim/nano/etc.) with the DECRYPTED file
# → you edit it normally (add, change secrets)
# → when you save and close, SOPS re-encrypts and writes to disk

# Check what's in the encrypted file (review in PR):
cat secrets/production.yaml      # see encrypted values
sops -d secrets/production.yaml  # see decrypted values (if you have the key)

# Edit an existing encrypted file:
sops secrets/production.yaml     # opens decrypted in editor

# Decrypt to stdout (for scripts):
sops -d secrets/production.yaml  # prints decrypted YAML

# Use in a script:
export $(sops -d secrets/production.yaml | yq '.database | to_entries[] | .key + "=" + .value' | xargs)
```

---

## SOPS vs Alternatives

| Tool | How It Works | Best For | Limitation |
|------|-------------|----------|-----------|
| **SOPS** | Encrypt files, commit encrypted to git | Files that belong with code | Requires key management |
| **HashiCorp Vault** | Central secret server, apps fetch at runtime | Large orgs, dynamic secrets | Complex to run, another service to manage |
| **AWS Secrets Manager** | AWS-hosted secret store, app reads via API | AWS-native apps | Vendor lock-in, costs per secret |
| **Kubernetes Sealed Secrets** | Encrypt k8s Secrets for git | Kubernetes-only | Kubernetes-specific |
| **External Secrets Operator** | Sync from Vault/AWS SM to k8s Secrets | K8s + existing secret manager | Doesn't replace the secret manager |
| **Doppler/Infisical** | SaaS secret manager | Teams wanting zero infra | SaaS dependency, cost |

**SOPS is not a replacement for AWS Secrets Manager or Vault** — it's a different tool. SOPS answers "how do I version-control the secret configuration files that define what secrets a service needs?" Vault/AWS SM answer "where do the actual secret values live at runtime?"

Many teams use BOTH:
- SOPS to encrypt Helm values files (what secrets the service needs, versioned in git)
- AWS Secrets Manager for runtime secret injection (ExternalSecrets reads from AWS SM)

---

## What SOPS Is Not

```
✗ SOPS is NOT a secret server. It doesn't serve secrets to your app at runtime.
✗ SOPS is NOT a key manager. It uses KMS, age, or PGP for key management.
✗ SOPS is NOT a certificate manager. Use cert-manager for TLS certs.
✗ SOPS is NOT dynamic secrets. It stores static files.
✓ SOPS IS a way to safely version-control secret configuration files.
✓ SOPS IS the answer to "how do I share encrypted secrets with my team via git?"
```

---

## Common Misunderstanding: "If someone has the key file, they have all secrets forever"

**The misunderstanding:** "If a developer leaves and they have the age key on their laptop, they can still decrypt our secrets."

**The reality:** This is the key rotation scenario. When a developer leaves:
1. Remove their public key from `.sops.yaml`
2. Run `sops updatekeys secrets/*.yaml` — this re-encrypts the DEK without their key
3. Their old key can no longer decrypt new or re-encrypted files
4. Historical git commits still have the old encrypted versions, but with key rotation the old DEK versions become useless

This is the same problem you'd have with any encryption system. SOPS makes key rotation practical — it takes minutes, not hours.

→ Continue to: `01-installation-and-setup.md`
