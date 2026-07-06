# SOPS — 08: Real-World Patterns

> **Last updated:** July 3, 2026
> **Covers:** Multi-environment setup, secret rotation, disaster recovery, migrating to SOPS, common pitfalls

**20-minute read. The patterns that come up in production deployments.**

---

## Pattern 1: The Multi-Environment Setup

A production-grade repo structure for three environments:

```
project/
  .sops.yaml                               ← key config (commit this)
  
  secrets/
    development.yaml                       ← SOPS encrypted
    staging.yaml                           ← SOPS encrypted
    production.yaml                        ← SOPS encrypted
  
  helm/
    vault-api/
      values.yaml                          ← plaintext non-secrets
      values.development.yaml              ← plaintext env-specific overrides
      values.staging.yaml                  ← plaintext env-specific overrides
      values.production.yaml              ← plaintext env-specific overrides
      values.secrets.development.yaml      ← SOPS encrypted secrets
      values.secrets.staging.yaml          ← SOPS encrypted secrets
      values.secrets.production.yaml       ← SOPS encrypted secrets
```

```yaml
# .sops.yaml
creation_rules:
  # Production: only KMS + tech leads (strictest)
  - path_regex: .*(production|prod).*\.(yaml|json|env)$
    kms: arn:aws:kms:ap-south-1:123456789012:alias/sops-production
    age: >-
      age1shashank...,
      age1techlead2...
    encrypted_regex: ^(password|secret|key|token|api_key|credential|private)$
  
  # Staging: KMS + all devs
  - path_regex: .*(staging|stage).*\.(yaml|json|env)$
    kms: arn:aws:kms:ap-south-1:123456789012:alias/sops-staging
    age: >-
      age1shashank...,
      age1developer2...,
      age1developer3...,
      age1ci-staging...
    encrypted_regex: ^(password|secret|key|token|api_key|credential|private)$
  
  # Development: age only — no AWS dependency
  - path_regex: .*(development|dev|local).*\.(yaml|json|env)$
    age: >-
      age1shashank...,
      age1developer2...,
      age1developer3...,
      age1developer4...
  
  # Fallback
  - path_regex: .*
    age: age1shashank...,age1developer2...
```

---

## Pattern 2: Secret Rotation

You need to rotate a secret (API key expired, employee left, regular rotation policy):

```bash
# Step 1: Edit the encrypted file
sops secrets/production.yaml

# In your editor, find and update the old key:
# Before: stripe.api_key: sk_live_oldkey123
# After:  stripe.api_key: sk_live_newkey456

# Save and close → SOPS re-encrypts automatically

# Step 2: Commit the change
git add secrets/production.yaml
git commit -m "rotate: stripe production API key (monthly rotation)"
git push origin main

# Step 3: PR review (optional but recommended for production)
# Reviewer sees: the field 'stripe.api_key' was changed
# Reviewer CANNOT see the old or new value (both encrypted)
# Reviewer can only confirm: yes, this file changed and was re-encrypted correctly

# Step 4: Deploy picks up the new value
# (ArgoCD or CI deploys, decrypts, updates the Kubernetes Secret)
```

### Rotating the Encryption Key Itself

When a developer leaves, or you want to rotate the KMS key:

```bash
# Step 1: Generate new age key (if rotating developer key)
age-keygen -o ~/.config/sops/age/keys.txt   # overwrites old key — CAREFUL

# Step 2: Update .sops.yaml with new/removed keys
# Remove the departed developer's public key
# Add any new keys

# Step 3: Re-encrypt ALL files with updated key set
find . -name "*.yaml" -path "*/secrets/*" | while read f; do
  echo "Updating keys for: $f"
  sops updatekeys "$f" --yes   # --yes skips confirmation
done

# Step 4: Verify all files were re-encrypted
git diff --stat   # should show all secrets files changed

# Step 5: Commit
git add -A
git commit -m "chore(sops): rotate keys (offboard developer2)"
git push
```

**KMS key rotation (AWS):**

```bash
# Enable automatic annual rotation for the KMS key
aws kms enable-key-rotation \
  --key-id arn:aws:kms:ap-south-1:123456789012:key/12345678-...

# Or manually rotate:
aws kms rotate-key-on-demand \
  --key-id arn:aws:kms:ap-south-1:123456789012:key/12345678-...

# After KMS key rotation:
# Existing files still decrypt (AWS maintains old key material for decryption)
# New encrypt operations use the new key material
# sops updatekeys re-encrypts DEKs with the new KMS key version
```

---

## Pattern 3: Bootstrapping — The Chicken-and-Egg Problem

"I need secrets to bootstrap my infrastructure (AWS credentials, Terraform state credentials). But SOPS needs cloud credentials to work. How do I encrypt the bootstrapping credentials?"

**Solution: Use age for bootstrapping secrets**

age doesn't depend on cloud infrastructure — just a key file on your machine. Use age to encrypt the credentials needed to bootstrap your cloud setup:

```yaml
# .sops.yaml
creation_rules:
  # Bootstrap credentials: age only (no cloud dependency)
  - path_regex: ^bootstrap/.*\.yaml$
    age: age1admin1...,age1admin2...   # only senior engineers
  
  # Everything else: use AWS KMS (once AWS is bootstrapped)
  - path_regex: .*
    kms: arn:aws:kms:...:alias/sops-main
    age: age1admin1...    # fallback for break-glass scenarios
```

```yaml
# bootstrap/aws-admin-credentials.yaml (encrypted with age)
aws:
  access_key_id: AKIAIOSFODNN7EXAMPLE    ← encrypted
  secret_access_key: wJalrXUtnFEMI...    ← encrypted
  region: ap-south-1

terraform:
  state_bucket: vault-terraform-state
  lock_table: vault-terraform-locks
```

This file is committed encrypted. On a fresh machine:
1. You have your age private key (backed up in password manager)
2. You decrypt the bootstrap credentials
3. You bootstrap the cloud infrastructure (creates KMS keys, etc.)
4. Now the rest of SOPS works

---

## Pattern 4: Break-Glass Access

Production KMS key is unavailable (AWS outage). Someone needs to access production secrets urgently.

**Defense: Always include age key as backup for critical secrets**

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/production\.yaml$
    kms: arn:aws:kms:ap-south-1:123456789012:alias/sops-production
    # Break-glass: tech lead age key as backup
    age: age1shashank...
```

The age recipient is a backup. If KMS is unavailable, the tech lead can decrypt with their age private key.

**Break-glass key management:**
```bash
# Store the break-glass age private key in an offline location:
# - Hardware security key (YubiKey)
# - Encrypted USB drive in physical safe
# - Password manager with MFA

# Verify the break-glass key works (periodically test):
SOPS_AGE_KEY_FILE=/path/to/breakglass/keys.txt sops -d secrets/production.yaml | head -5
```

---

## Pattern 5: Detecting Drift — Are Your Secrets Up-to-Date?

How do you know if the secrets in Kubernetes match what's in git?

```bash
# Compare current k8s secret with what SOPS would produce
kubectl get secret vault-api-secrets -n production \
  -o jsonpath='{.data.DATABASE_PASSWORD}' | base64 -d > /tmp/k8s-secret

sops -d --extract '["database"]["password"]' secrets/production.yaml > /tmp/sops-secret

diff /tmp/k8s-secret /tmp/sops-secret
# If output: drift detected — cluster secret doesn't match git

# Clean up
rm /tmp/k8s-secret /tmp/sops-secret
```

**Automated drift detection in CI:**

```yaml
# .github/workflows/drift-check.yml
on:
  schedule:
  - cron: '0 9 * * 1'   # every Monday

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Check for drift
      run: |
        # Decrypt current SOPS value
        EXPECTED=$(sops -d --extract '["database"]["password"]' secrets/production.yaml)
        
        # Get current k8s secret value
        ACTUAL=$(kubectl get secret vault-api-secrets -n production \
          -o jsonpath='{.data.DATABASE_PASSWORD}' | base64 -d)
        
        if [ "$EXPECTED" != "$ACTUAL" ]; then
          echo "DRIFT DETECTED: database password differs"
          exit 1
        fi
```

---

## Pattern 6: Migrating from Other Secret Managers

### From Plaintext Files in Git

```bash
# You have: secrets.yaml (plaintext, committed to git)
# You want: secrets.yaml (SOPS encrypted)

# Step 1: Set up .sops.yaml with correct keys
# Step 2: Encrypt in-place
sops -e -i secrets.yaml

# Step 3: Commit the encrypted version
git add secrets.yaml
git commit -m "chore(security): encrypt secrets with SOPS"

# Step 4: Rewrite git history to remove the plaintext version
# WARNING: This rewrites history — coordinate with your team first
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch secrets.yaml" \
  --prune-empty --tag-name-filter cat -- --all

# Or use BFG Repo Cleaner (faster):
bfg --delete-files secrets.yaml
git push origin --force --all

# Step 5: Invalidate and rotate all secrets that were exposed
# The git history rewrite doesn't help if someone already cloned the repo
# Rotate every secret that was in the plaintext file
```

### From AWS Secrets Manager to SOPS

```bash
# Export secrets from AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id prod/vault-api/database \
  --query SecretString --output text | jq '.' > /tmp/secrets-raw.json

# Convert to YAML format and encrypt
python3 -c "
import json, yaml, sys
data = json.load(open('/tmp/secrets-raw.json'))
print(yaml.dump({'database': data}))
" > /tmp/secrets.yaml

sops -e /tmp/secrets.yaml > secrets/production.yaml

# Cleanup
rm /tmp/secrets-raw.json /tmp/secrets.yaml
```

---

## Troubleshooting Common Issues

### "could not decrypt key"

```bash
# Error: Failed to decrypt key
# Cause: Your private key doesn't match any recipient in the file

# Check who can decrypt this file
sops --show-master-keys -d secrets/production.yaml

# Check what key you have
cat ~/.config/sops/age/keys.txt | grep "public key"

# If your key is not in the file, ask a team member to add you:
# They run: sops updatekeys secrets/production.yaml (after adding you to .sops.yaml)
```

### "MAC verification failed"

```bash
# Error: MAC verification failed
# Cause: File was modified after encryption (someone edited the encrypted values directly)
# This is a security feature — SOPS detects tampering

# If legitimate: re-encrypt the file fresh
sops -d secrets/production.yaml > /tmp/plain.yaml   # if you can decrypt
sops -e /tmp/plain.yaml > secrets/production.yaml   # re-encrypt clean
rm /tmp/plain.yaml

# If merge conflict corrupted the file:
# Get the version from before the conflict and decrypt/re-encrypt
git show HEAD~1:secrets/production.yaml | sops --input-type yaml -d /dev/stdin
```

### "kms: failed to create session"

```bash
# Error: Failed to create KMS session
# Cause: AWS credentials not configured or wrong region

aws sts get-caller-identity   # verify AWS credentials
aws kms describe-key --key-id alias/sops-production  # verify key access

# Check if you have the decrypt permission
aws kms decrypt \
  --key-id alias/sops-production \
  --ciphertext-blob <test-value> \
  --region ap-south-1
```

### "path not found in creation_rules"

```bash
# Warning: No match for 'some/path/file.yaml' in '.sops.yaml'
# SOPS falls back to flags or prompts for a key

# Fix: add a catch-all rule at the bottom of .sops.yaml
creation_rules:
  # ... specific rules ...
  - path_regex: .*        # catch-all
    age: age1dev...
```

---

## Security Checklist

```
Repository:
  □ .sops.yaml committed (public keys, not private)
  □ All secrets files encrypted (check: grep -r "sops:" secrets/)
  □ .gitignore includes decrypted variants (*.dec.yaml, *.plaintext.*)
  □ Pre-commit hook prevents plaintext secrets from being committed

Keys:
  □ Each person has their own age key (not shared keys)
  □ CI has a dedicated machine key (not a developer's key)
  □ Production KMS separate from staging KMS
  □ Break-glass age key backed up offline
  □ Private keys NOT in git, not in any config file

Access Control:
  □ Production secrets: only tech leads + production CI
  □ Staging secrets: all developers + CI
  □ Development secrets: all developers (no CI dependency)
  □ KMS decrypt-only for CI (not encrypt)

Procedures:
  □ Offboarding: run sops updatekeys after removing developer from .sops.yaml
  □ Key rotation: scheduled (quarterly) or event-driven (employee leaves)
  □ Audit: monthly review of who has access to production key
  □ Break-glass access tested quarterly
```

---

## Common Misunderstanding: "SOPS is complex and slows down development"

**The misunderstanding:** "Setting up SOPS takes a week and developers will hate it."

**The day-to-day developer experience with SOPS:**

```bash
# Need to check what database host is configured?
sops -d secrets/production.yaml | grep host
# output: host: db.production.internal

# Need to update the Stripe key?
sops secrets/production.yaml   # opens in vim/nano
# change the value, save, done

# That's it.
```

The complexity is in setup (one-time). After `.sops.yaml` is configured, the daily workflow is:
1. `sops secrets/environment.yaml` — opens decrypted file in editor
2. Edit the values
3. Save → auto-encrypted
4. `git add && git commit && git push`

Most developers never think about encryption. They just run `sops file.yaml` and work with it. The encryption is transparent.

→ Continue to: `README.md`
