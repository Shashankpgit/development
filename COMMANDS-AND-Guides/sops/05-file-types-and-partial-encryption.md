# SOPS — 05: File Types and Partial Encryption

> **Last updated:** July 3, 2026
> **Covers:** YAML, JSON, .env, INI, binary files — how SOPS handles each, partial encryption patterns

**20-minute read. SOPS isn't just for YAML — it handles the file formats you actually use.**

---

## Supported File Types

SOPS auto-detects format from file extension:

| Extension | Format | What's Encrypted |
|-----------|--------|-----------------|
| `.yaml`, `.yml` | YAML | All values (or matching encrypted_regex) |
| `.json` | JSON | All values (or matching encrypted_regex) |
| `.env` | dotenv | All values |
| `.ini` | INI | All values |
| `.txt`, others | Binary | Entire file contents |

---

## YAML Files (Most Common)

```yaml
# secrets/production.yaml — before encryption
database:
  host: db.production.internal
  port: 5432
  password: superSecret123
  ssl_cert: |
    -----BEGIN CERTIFICATE-----
    MIIFazCCA1O...
    -----END CERTIFICATE-----

redis:
  url: redis://cache.internal:6379
  password: redisSuperSecret

api_keys:
  stripe: sk_live_abcdef123456789
  sendgrid: SG.xxxxxxxxxxxxx
```

```bash
# Encrypt (SOPS auto-detects YAML from extension)
sops -e -i secrets/production.yaml

# After encryption:
database:
    host: ENC[AES256_GCM,data:abc...,type:str]
    port: ENC[AES256_GCM,data:NDU...,type:int]  # ← type preserved (int)
    password: ENC[AES256_GCM,data:c3Vw...,type:str]
    ssl_cert: ENC[AES256_GCM,data:LS0t...,type:str]

redis:
    url: ENC[AES256_GCM,data:cmVk...,type:str]
    password: ENC[AES256_GCM,data:cmVk...,type:str]

api_keys:
    stripe: ENC[AES256_GCM,data:c2tf...,type:str]
    sendgrid: ENC[AES256_GCM,data:U0cu...,type:str]
sops:
    ...
```

SOPS preserves the **type** of each value (string, int, bool, float). When decrypted, the port is an integer (5432), not a string ("5432").

### Nested Structures and Lists

```yaml
# SOPS handles arbitrary nesting and lists
services:
  - name: vault-api
    endpoint: https://api.internal
    api_key: secret123          ← encrypted
  - name: vault-worker
    endpoint: https://worker.internal
    api_key: anothersecret      ← encrypted
```

---

## JSON Files

```json
// secrets/aws-credentials.json — before encryption
{
  "aws_access_key_id": "AKIAIOSFODNN7EXAMPLE",
  "aws_secret_access_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "aws_region": "ap-south-1",
  "s3_bucket": "vault-backups"
}
```

```bash
sops -e -i secrets/aws-credentials.json
```

```json
// After encryption
{
  "aws_access_key_id": "ENC[AES256_GCM,data:QUTJQQ==,iv:...,tag:...,type:str]",
  "aws_secret_access_key": "ENC[AES256_GCM,data:d0phb...,iv:...,tag:...,type:str]",
  "aws_region": "ENC[AES256_GCM,data:YXAt...,iv:...,tag:...,type:str]",
  "s3_bucket": "ENC[AES256_GCM,data:dmF1...,iv:...,tag:...,type:str]",
  "sops": {
    "kms": [],
    "age": [...],
    "lastmodified": "2026-07-03T10:22:31Z",
    ...
  }
}
```

---

## .env Files

The `.env` format is common for Node.js and Docker-based projects.

```bash
# secrets/.env.production — before encryption
DATABASE_URL=postgresql://admin:superSecret@db.internal:5432/vault
JWT_SECRET=very-long-random-secret-key
STRIPE_KEY=sk_live_abcdef123456789
SENDGRID_API_KEY=SG.xxxxxxxxxxxxx
NODE_ENV=production
PORT=3000
```

```bash
sops --input-type dotenv --output-type dotenv -e -i secrets/.env.production
# or if the extension is .env, SOPS auto-detects
sops -e -i secrets/.env.production
```

```bash
# After encryption
DATABASE_URL=ENC[AES256_GCM,data:cG9zdGdyZXNx...,type:str]
JWT_SECRET=ENC[AES256_GCM,data:dmVyeS1sb25n...,type:str]
STRIPE_KEY=ENC[AES256_GCM,data:c2tfbGl2ZV9h...,type:str]
SENDGRID_API_KEY=ENC[AES256_GCM,data:U0cudA==...,type:str]
NODE_ENV=ENC[AES256_GCM,data:cHJvZHVjdGlvbg==,type:str]
PORT=ENC[AES256_GCM,data:MzAwMA==,type:int]
```

### Using Decrypted .env in Your App

```bash
# Method 1: Use sops exec-env to inject as environment variables
sops exec-env secrets/.env.production 'node src/server.js'

# Method 2: Source into shell (careful — values visible in process list)
eval $(sops -d secrets/.env.production | sed 's/^/export /')
node src/server.js

# Method 3: Write to temp file and source
sops -d secrets/.env.production > /tmp/.env && source /tmp/.env && rm /tmp/.env
node src/server.js
```

---

## Binary / Text Files

For files that don't fit YAML/JSON/ENV — certificates, private keys, arbitrary text:

```bash
# Encrypt a complete file (binary mode)
sops -e --input-type binary --output-type binary private-key.pem > private-key.pem.enc

# Decrypt
sops -d --input-type binary --output-type binary private-key.pem.enc > private-key.pem

# Or let extension hint (SOPS uses binary mode for .txt and unknown extensions)
sops -e -i backup.sh         # encrypts the entire shell script
sops -e -i config.toml       # encrypts the entire TOML file
```

**When to use binary vs YAML:**
- Binary mode: when you need the ENTIRE file encrypted (shell scripts with embedded credentials, PEM files, arbitrary text)
- YAML/JSON/ENV mode: when you want structure preserved and diffs readable

---

## Partial Encryption — The Real-World Pattern

Encrypting everything makes PR reviews hard. If every value is encrypted, reviewers can't see what changed.

The solution: encrypt ONLY secrets, leave non-sensitive config in plaintext.

### Pattern 1: encrypted_regex in .sops.yaml

```yaml
# .sops.yaml
creation_rules:
  - path_regex: ^helm/.*values.*\.yaml$
    age: age1dev...
    # Only encrypt fields with these names (anywhere in the YAML tree)
    encrypted_regex: ^(password|secret|key|token|credential|private|api_key|webhook)$
```

```yaml
# helm/vault-api/values.yaml — before encryption
replicaCount: 2
image:
  repository: ghcr.io/sanketika/vault-api
  tag: "v1.2.3"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  host: api.vault.example.com
  tls:
    secretName: vault-api-tls

config:
  logLevel: info
  nodeEnv: production

secrets:
  databasePassword: superSecret123     ← will be encrypted
  jwtSecret: very-long-key             ← will be encrypted
  stripeApiKey: sk_live_abc123         ← will be encrypted
```

After encryption:
```yaml
replicaCount: 2                         ← plaintext (not a secret)
image:
  repository: ghcr.io/sanketika/vault-api  ← plaintext
  tag: "v1.2.3"                        ← plaintext
  pullPolicy: IfNotPresent              ← plaintext

service:
  type: ClusterIP                       ← plaintext
  port: 80                              ← plaintext

ingress:
  host: api.vault.example.com           ← plaintext
  tls:
    secretName: vault-api-tls           ← plaintext

config:
  logLevel: info                        ← plaintext
  nodeEnv: production                   ← plaintext

secrets:
  databasePassword: ENC[...]            ← ENCRYPTED
  jwtSecret: ENC[...]                   ← ENCRYPTED
  stripeApiKey: ENC[...]                ← ENCRYPTED
```

**PR Review:** Reviewer sees that `replicaCount` changed from 2 to 3 (plaintext). They can't see the secret values (encrypted). This is the ideal outcome.

### Pattern 2: Separate Files (All-or-Nothing Encryption)

Keep secrets and non-secrets in separate files:

```
helm/vault-api/
  values.yaml         ← non-secret config, not encrypted, committed normally
  values.secrets.yaml ← ALL values encrypted (all are secrets)
```

```yaml
# values.yaml (plaintext, in git)
replicaCount: 2
image:
  repository: ghcr.io/sanketika/vault-api
  tag: "v1.2.3"
config:
  logLevel: info
  nodeEnv: production
```

```yaml
# values.secrets.yaml (fully encrypted with SOPS)
database:
  password: superSecret123    ← will be encrypted
jwt:
  secret: very-long-key       ← will be encrypted
stripe:
  apiKey: sk_live_abc123      ← will be encrypted
```

```bash
# When deploying with helm-secrets:
helm secrets upgrade vault-app ./helm/vault-api/ \
  -f helm/vault-api/values.yaml \
  -f helm/vault-api/values.secrets.yaml   ← helm-secrets decrypts this automatically
```

---

## Generating a Secrets Template

When onboarding a new service, provide a template with the STRUCTURE but no values:

```yaml
# secrets/TEMPLATE.yaml — NOT encrypted, shows what's needed
database:
  host: ""          # PostgreSQL host
  port: 5432        # PostgreSQL port
  user: ""          # Database username
  password: ""      # Database password — REQUIRED

jwt:
  secret: ""        # Minimum 32 random characters — REQUIRED
  expiry: "24h"     # Token expiry duration

stripe:
  api_key: ""       # From Stripe dashboard — REQUIRED (prod: sk_live_*)
  webhook_secret: "" # From Stripe webhook settings — OPTIONAL
```

```bash
# New developer copies template and fills in values
cp secrets/TEMPLATE.yaml secrets/development.yaml
# Edit secrets/development.yaml with actual values
sops -e -i secrets/development.yaml
# Now commit secrets/development.yaml (encrypted)
```

---

## Detecting Unencrypted Files in Git

Add a pre-commit hook to prevent accidentally committing plaintext secrets:

```bash
# .git/hooks/pre-commit  (or managed by pre-commit framework)
#!/bin/bash

# Check if any tracked secrets files are plaintext
for f in $(git diff --cached --name-only | grep -E 'secrets/.*\.(yaml|json|env)$'); do
  if ! grep -q "^sops:" "$f" && ! grep -q "ENC\[AES256_GCM" "$f"; then
    echo "ERROR: $f appears to be a plaintext secrets file (not encrypted with SOPS)"
    echo "Run: sops -e -i $f"
    exit 1
  fi
done
exit 0
```

Or use the `pre-commit` framework:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/nicholasamorim/pre-commit-sops
    rev: v0.1.0
    hooks:
      - id: forbid-secret-plaintext
        files: secrets/.*\.(yaml|json|env)$
```

---

## Common Misunderstanding: "SOPS only works with YAML"

**The misunderstanding:** "I use JSON for my config files, so SOPS won't work for me."

**The reality:** SOPS handles YAML, JSON, .env, INI, and binary formats. The workflow is identical — SOPS detects the format from the file extension and handles the rest.

More importantly: SOPS can CONVERT between formats:

```bash
# Encrypt a JSON file, output as YAML (for readability)
sops --input-type json --output-type yaml -e secrets.json > secrets.yaml

# Decrypt a YAML file and output as JSON (for a tool that needs JSON)
sops --output-type json -d secrets.yaml

# Use a specific format regardless of extension
sops --input-type dotenv --output-type dotenv -e .env.production
```

→ Continue to: `06-kubernetes-and-helm.md`
