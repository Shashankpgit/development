# SOPS — 04: The .sops.yaml Configuration File

> **Last updated:** July 3, 2026
> **Covers:** .sops.yaml creation rules, path_regex, key groups, shamir secret sharing, encrypted regex

**20-minute read. .sops.yaml is what makes SOPS automatic — no flags, no remembering which key to use.**

---

## Why .sops.yaml Exists

Without `.sops.yaml`, every SOPS command needs explicit flags:

```bash
# Without .sops.yaml — tedious
sops --age age1dev1...,age1dev2...,age1ci... \
     --encrypted-regex '^(password|secret|key|token)$' \
     secrets/production.yaml

# With .sops.yaml — clean
sops secrets/production.yaml
```

`.sops.yaml` is a project-level config that defines:
- Which keys to use for which files
- What patterns to encrypt
- Key groups (multiple keys must agree)

**Commit `.sops.yaml` to git.** It contains only public keys and configuration — no secrets.

---

## Basic Structure

```yaml
# .sops.yaml
creation_rules:
  - path_regex: <regex>        # which files this rule applies to
    kms: <arn>                 # AWS KMS key ARN(s)
    gcp_kms: <resource>        # GCP KMS key resource
    azure_kv: <vault-url>      # Azure Key Vault URL
    hc_vault: <vault-path>     # HashiCorp Vault key path
    age: <pubkey1,pubkey2,...>  # age public keys (comma-separated)
    encrypted_regex: <regex>   # which keys to encrypt (default: all)
    key_groups:                # advanced: require multiple keys
    - ...
```

Rules are evaluated top-to-bottom. The first matching rule wins.

---

## Path Regex — Which Rule Applies

```yaml
creation_rules:
  # Exact file match
  - path_regex: ^secrets/production\.yaml$
    age: age1prod...

  # All YAML files in secrets/
  - path_regex: ^secrets/.*\.yaml$
    age: age1dev...

  # Anything with "prod" or "production" in the path
  - path_regex: .*(prod|production).*
    age: age1techleads...

  # All .env files
  - path_regex: .*\.env$
    age: age1dev...

  # Fallback — anything not matched above
  - path_regex: .*
    age: age1dev...
```

**Important:** path_regex is matched against the file path relative to where `.sops.yaml` lives.

```
project/
  .sops.yaml          ← here
  secrets/
    production.yaml   ← path: secrets/production.yaml
    staging.yaml      ← path: secrets/staging.yaml
```

---

## Real-World Multi-Environment .sops.yaml

```yaml
# .sops.yaml

creation_rules:
  # Production: strict — KMS + only tech leads
  - path_regex: ^(secrets|config)/production.*\.(yaml|json|env)$
    kms: arn:aws:kms:ap-south-1:123456789012:alias/sops-production
    age: >-
      age1shashank54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p,
      age1techlead2xyz789abc123def456ghi789jkl012mno345pqr678stu901vwx

  # Staging: KMS + all devs
  - path_regex: ^(secrets|config)/staging.*\.(yaml|json|env)$
    kms: arn:aws:kms:ap-south-1:123456789012:alias/sops-staging
    age: >-
      age1shashank...,
      age1developer2...,
      age1developer3...,
      age1ci-staging...

  # Development: age only — no AWS dependency for local dev
  - path_regex: ^(secrets|config)/development.*\.(yaml|json|env)$
    age: >-
      age1shashank...,
      age1developer2...,
      age1developer3...,
      age1developer4...

  # All other files: age for all devs
  - path_regex: .*
    age: >-
      age1shashank...,
      age1developer2...,
      age1developer3...
```

---

## encrypted_regex — Partial Encryption

By default, SOPS encrypts ALL values in a file. Sometimes you want to encrypt only specific fields.

```yaml
# .sops.yaml with partial encryption
creation_rules:
  - path_regex: ^config/.*\.yaml$
    age: age1dev...
    # Only encrypt fields whose KEY matches this regex
    encrypted_regex: ^(password|secret|key|token|api_key|private|credential)$
```

Now a config file like this:

```yaml
# config/app.yaml (before encryption)
app:
  name: vault-api               # not a secret — won't be encrypted
  version: "1.2.3"             # not a secret — won't be encrypted
  log_level: info              # not a secret — won't be encrypted
  
database:
  host: db.internal            # not matching regex — won't be encrypted
  port: 5432                   # not matching regex — won't be encrypted
  user: admin                  # not matching regex — won't be encrypted
  password: superSecret123     # matches 'password' — WILL be encrypted

jwt:
  secret: very-long-key        # matches 'secret' — WILL be encrypted
  expiry: 24h                  # not matching — won't be encrypted

stripe:
  api_key: sk_live_abc123      # matches 'api_key' — WILL be encrypted
  webhook_secret: whsec_xyz    # matches 'secret' — WILL be encrypted
```

After encryption:

```yaml
app:
  name: vault-api              ← plaintext (not a secret)
  version: "1.2.3"            ← plaintext
  log_level: info             ← plaintext

database:
  host: db.internal           ← plaintext (hostname not sensitive here)
  port: 5432                  ← plaintext
  user: admin                 ← plaintext
  password: ENC[...]          ← ENCRYPTED

jwt:
  secret: ENC[...]            ← ENCRYPTED
  expiry: 24h                 ← plaintext

stripe:
  api_key: ENC[...]           ← ENCRYPTED
  webhook_secret: ENC[...]    ← ENCRYPTED
```

**Why partial encryption is useful:**
- PR diffs show non-secret config changes clearly
- Debugging is easier ("what hostname is this using?" — visible without decryption)
- Operators can read non-sensitive config without decryption access

---

## encrypted_suffix — Alternative Approach

Instead of regex, use a naming convention:

```yaml
# .sops.yaml
creation_rules:
  - path_regex: .*\.yaml$
    age: age1dev...
    encrypted_suffix: _secret  # only encrypt keys ending in _secret
```

```yaml
# Values file — keys ending in _secret get encrypted
database_host: db.internal          ← plaintext
database_password_secret: abc123    ← ENCRYPTED (ends in _secret)
jwt_expiry: 24h                     ← plaintext  
jwt_secret: very-long-key           ← ENCRYPTED (ends in _secret)
```

---

## Key Groups — Shamir's Secret Sharing

Key groups let you require MULTIPLE keys to decrypt a file. This is for high-security scenarios.

```yaml
# .sops.yaml with key groups
creation_rules:
  - path_regex: ^secrets/nuclear-launch-codes\.yaml$
    key_groups:
    
    # Group 1: AWS KMS (for CI/CD)
    - kms:
      - arn: arn:aws:kms:...:alias/sops-prod
    
    # Group 2: At least 2 of 3 tech leads must agree
    - age:
      - age1shashank...     # tech lead 1
      - age1techlead2...    # tech lead 2
      - age1techlead3...    # tech lead 3
      shamir_threshold: 2   # need 2 out of 3 to decrypt
```

With `shamir_threshold: 2`:
- 1 tech lead alone cannot decrypt
- 2 tech leads together can decrypt
- Even if tech lead 1 is away, tech leads 2+3 can still decrypt

This implements a form of two-person integrity for the highest-sensitivity secrets.

**Common use cases for key groups:**
- Financial secrets (payment processor master keys)
- Root/admin credentials
- Encryption master keys
- Compliance-required two-person authorization

---

## Updating Keys in Existing Files

When you change `.sops.yaml` (add/remove keys), you need to re-encrypt existing files:

```bash
# Re-encrypt a single file with current .sops.yaml keys
sops updatekeys secrets/production.yaml

# Re-encrypt all files matching a pattern
find secrets/ -name "*.yaml" | xargs -I{} sops updatekeys {}

# Or with a loop:
for f in secrets/*.yaml config/*.yaml; do
  echo "Updating keys for: $f"
  sops updatekeys "$f"
done

# Commit the re-encrypted files
git add -A
git commit -m "chore(sops): update encryption keys (add developer4, remove developer2)"
```

---

## Checking Which Rule Applies to a File

```bash
# Test which creation rule would match a file
sops --verbose --dry-run secrets/production.yaml 2>&1 | head -20

# Or simply try to decrypt and see which keys are listed
sops --show-master-keys -d secrets/production.yaml
```

---

## .sops.yaml for a Microservices Monorepo

```yaml
# .sops.yaml at repo root
creation_rules:

  # Each service has its own secrets directory
  # Production: only that service's team + tech leads
  - path_regex: ^services/vault-api/secrets/production\.yaml$
    kms: arn:aws:kms:...:alias/sops-vault-api-prod
    age: age1shashank...,age1backend-lead...

  - path_regex: ^services/vault-frontend/secrets/production\.yaml$
    kms: arn:aws:kms:...:alias/sops-vault-frontend-prod
    age: age1shashank...,age1frontend-lead...

  # Staging: respective team + CI
  - path_regex: ^services/.*/secrets/staging\.yaml$
    kms: arn:aws:kms:...:alias/sops-staging
    age: age1shashank...,age1developer2...,age1developer3...

  # Development: all devs, no KMS dependency
  - path_regex: ^services/.*/secrets/development\.yaml$
    age: >-
      age1shashank...,
      age1developer2...,
      age1developer3...,
      age1developer4...

  # Infrastructure secrets: DevOps team only
  - path_regex: ^infrastructure/.*\.yaml$
    kms: arn:aws:kms:...:alias/sops-infra
    age: age1shashank...,age1devops-engineer...

  # Default fallback
  - path_regex: .*
    age: age1shashank...,age1developer2...
```

---

## Common Misunderstanding: "I need to specify keys every time I use sops"

**The misunderstanding:** "Every sops command needs `--age` or `--kms` flags."

**The reality:**
```bash
# With .sops.yaml → no flags needed
sops secrets/production.yaml           # uses creation_rules automatically
sops -d secrets/staging.yaml           # decrypts using the keys in the file metadata

# Flags are only needed if:
# 1. You don't have a .sops.yaml
# 2. You're overriding what .sops.yaml specifies
# 3. Creating a file in a path not covered by any rule
```

Put `.sops.yaml` in your project root, define rules for all your secrets paths, and then sops commands are clean and simple. The config file is the investment that pays for itself on day 2.

→ Continue to: `05-file-types-and-partial-encryption.md`
