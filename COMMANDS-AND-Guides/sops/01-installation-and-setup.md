# SOPS — 01: Installation and First Encryption

> **Last updated:** July 3, 2026
> **Covers:** Installing SOPS and age, generating your first key, encrypting and decrypting a file, understanding the encrypted format

**20-minute read. By the end of this file you will have SOPS working and your first secret encrypted.**

---

## Installing SOPS

Pick the block that matches your OS and CPU architecture.

```bash
# ── macOS (Intel or Apple Silicon — Homebrew handles the arch) ──────
brew install sops

# ── Linux: Ubuntu/Debian — x86_64 ───────────────────────────────────
curl -LO https://github.com/getsops/sops/releases/download/v3.13.2/sops_3.13.2_amd64.deb
sudo dpkg -i sops_3.13.2_amd64.deb
rm sops_3.13.2_amd64.deb

# ── Linux: Ubuntu/Debian — ARM64 (Graviton EC2, Raspberry Pi) ───────
curl -LO https://github.com/getsops/sops/releases/download/v3.13.2/sops_3.13.2_arm64.deb
sudo dpkg -i sops_3.13.2_arm64.deb
rm sops_3.13.2_arm64.deb

# ── Linux: Amazon Linux 2023 / RHEL / Fedora — x86_64 ───────────────
curl -LO https://github.com/getsops/sops/releases/download/v3.13.2/sops-3.13.2-1.x86_64.rpm
sudo rpm -ivh sops-3.13.2-1.x86_64.rpm
rm sops-3.13.2-1.x86_64.rpm

# ── Linux: Amazon Linux 2023 / RHEL — ARM64 (Graviton EC2) ──────────
curl -LO https://github.com/getsops/sops/releases/download/v3.13.2/sops-3.13.2-1.aarch64.rpm
sudo rpm -ivh sops-3.13.2-1.aarch64.rpm
rm sops-3.13.2-1.aarch64.rpm

# ── Linux: Any distro — x86_64 (universal binary fallback) ──────────
curl -LO https://github.com/getsops/sops/releases/download/v3.13.2/sops-v3.13.2.linux.amd64
chmod +x sops-v3.13.2.linux.amd64
sudo mv sops-v3.13.2.linux.amd64 /usr/local/bin/sops

# ── Linux: Any distro — ARM64 (universal binary fallback) ───────────
curl -LO https://github.com/getsops/sops/releases/download/v3.13.2/sops-v3.13.2.linux.arm64
chmod +x sops-v3.13.2.linux.arm64
sudo mv sops-v3.13.2.linux.arm64 /usr/local/bin/sops

# ── Verify (all platforms) ───────────────────────────────────────────
sops --version
# sops 3.13.2 (latest stable, July 2026)
```

**How to check your CPU architecture on Linux:**
```bash
uname -m
# x86_64  → use amd64 packages
# aarch64 → use arm64 packages
```

---

## Installing age (The Recommended Backend for Starting Out)

age (lowercase) is a simple, modern encryption tool. It generates a keypair: a public key (shareable) and a private key (secret, stays on your machine).

```bash
# ── macOS (Intel or Apple Silicon) ──────────────────────────────────
brew install age

# ── Linux: Ubuntu 22.04+ / Debian 12+ (available in official repos) ─
sudo apt install age

# ── Linux: Ubuntu < 22.04 / older Debian — x86_64 ───────────────────
curl -LO https://github.com/FiloSottile/age/releases/download/v1.2.0/age-v1.2.0-linux-amd64.tar.gz
tar -xzf age-v1.2.0-linux-amd64.tar.gz
sudo mv age/age age/age-keygen /usr/local/bin/
rm -rf age/ age-v1.2.0-linux-amd64.tar.gz

# ── Linux: ARM64 — Graviton EC2, Raspberry Pi (any distro) ──────────
curl -LO https://github.com/FiloSottile/age/releases/download/v1.2.0/age-v1.2.0-linux-arm64.tar.gz
tar -xzf age-v1.2.0-linux-arm64.tar.gz
sudo mv age/age age/age-keygen /usr/local/bin/
rm -rf age/ age-v1.2.0-linux-arm64.tar.gz

# ── Linux: Amazon Linux 2023 / RHEL (no native package — use binary) ─
# Run the x86_64 binary method above (or arm64 if using Graviton)
# Amazon Linux 2023 example:
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
curl -LO "https://github.com/FiloSottile/age/releases/download/v1.2.0/age-v1.2.0-linux-${ARCH}.tar.gz"
tar -xzf "age-v1.2.0-linux-${ARCH}.tar.gz"
sudo mv age/age age/age-keygen /usr/local/bin/
rm -rf age/ "age-v1.2.0-linux-${ARCH}.tar.gz"

# ── Verify (all platforms) ───────────────────────────────────────────
age --version
# v1.2.0
```

---

## Generating Your age Key

```bash
# Generate a key and store it in the standard location
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# Output:
# Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
# 
# The file contents look like:
# # created: 2026-07-03T10:00:00Z
# # public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
# AGE-SECRET-KEY-1QJJF7XQ6V...   ← KEEP THIS SECRET
```

**What these two things are:**
- **Public key** (`age1ql3z...`): Share this with anyone who needs to encrypt files FOR you, or with team members who need to add you to a SOPS file. It's not a secret.
- **Private key** (`AGE-SECRET-KEY-1...`): This is what decrypts files. Never share it, never commit it to git, treat it like a password. If lost, you lose access to anything encrypted only for you.

```bash
# Where SOPS looks for the private key automatically
~/.config/sops/age/keys.txt

# Or set via environment variable
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

---

## Your First Encryption

Let's encrypt a simple secrets file:

```bash
# Create a test directory
mkdir -p ~/test-sops && cd ~/test-sops

# Get your public key (printed when you generated the key)
# or read it from the keys file:
cat ~/.config/sops/age/keys.txt | grep "public key"
# # public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# Create an encrypted YAML file for this key
sops --age age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p \
     --encrypt \
     --in-place \
     secrets.yaml

# → This opens your editor. Type your secrets:
```

In the editor, type:

```yaml
database:
  host: db.production.internal
  port: 5432
  user: admin
  password: superSecret123

jwt:
  secret: very-long-random-secret-key-here

stripe:
  api_key: sk_live_abcdef123456789
  webhook_secret: whsec_xyz789
```

Save and close the editor. SOPS encrypts and writes back to disk.

---

## The Encrypted File Format

After encryption, `secrets.yaml` looks like this:

```yaml
database:
    host: ENC[AES256_GCM,data:Fm4HGC/NdJmtQJI=,iv:XWG...,tag:ABc...,type:str]
    port: ENC[AES256_GCM,data:NDUYM=,iv:XWG...,tag:ABc...,type:int]
    user: ENC[AES256_GCM,data:YWRtaW4=,iv:XWG...,tag:ABc...,type:str]
    password: ENC[AES256_GCM,data:c3VwZXJTZWNyZXQxMjM=,iv:XWG...,tag:ABc...,type:str]
jwt:
    secret: ENC[AES256_GCM,data:dmVyeS1sb25n...,iv:XWG...,tag:ABc...,type:str]
stripe:
    api_key: ENC[AES256_GCM,data:c2tfbGl2ZV9hYmM=,iv:XWG...,tag:ABc...,type:str]
    webhook_secret: ENC[AES256_GCM,data:d2hzZWNfeHl6Nzg5,iv:XWG...,tag:ABc...,type:str]
sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault: []
    age:
    -   recipient: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
        enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBBOEZGcm...
            -----END AGE ENCRYPTED FILE-----
    lastmodified: "2026-07-03T10:22:31Z"
    mac: ENC[AES256_GCM,data:ABcDe...,iv:XWG...,tag:ABc...,type:str]
    version: 3.13.2
```

**Anatomy of the encrypted file:**

```
database:            ← STRUCTURE visible (keys are not encrypted)
  password: ENC[...] ← VALUE encrypted
  
sops:                ← METADATA block at bottom
  age:               ← Who can decrypt this file
    - recipient:     ← The public key that can decrypt
      enc: ...       ← The DEK (Data Encryption Key), encrypted for that recipient
  lastmodified:      ← Timestamp
  mac:               ← Message Authentication Code (detects tampering)
  version:           ← SOPS version used
```

The `sops.age[].enc` block is the encrypted DEK. SOPS uses your private age key to decrypt this, then uses the DEK to decrypt all the values.

---

## Core Commands

```bash
# ── ENCRYPT ──────────────────────────────────────────────────────

# Encrypt a new file (opens editor)
sops secrets.yaml

# Encrypt an existing plaintext file in-place
sops --encrypt --in-place secrets.yaml

# Encrypt to a new file (keep original)
sops --encrypt secrets.yaml > secrets.enc.yaml

# Encrypt from stdin
echo '{"password": "secret"}' | sops --encrypt --input-type json --output-type json /dev/stdin


# ── DECRYPT ──────────────────────────────────────────────────────

# Decrypt to stdout (see all values)
sops --decrypt secrets.yaml

# Decrypt to a file
sops --decrypt secrets.yaml > secrets.plaintext.yaml  # NEVER commit this file!

# Decrypt a specific key only
sops --decrypt --extract '["database"]["password"]' secrets.yaml
# Output: superSecret123


# ── EDIT ─────────────────────────────────────────────────────────

# Edit an encrypted file (decrypts, opens editor, re-encrypts on save)
sops secrets.yaml

# This is the most common operation — SOPS handles the encrypt/decrypt cycle


# ── READ WITHOUT EDITOR ───────────────────────────────────────────

# Get a specific value (useful in scripts)
sops --decrypt --extract '["jwt"]["secret"]' secrets.yaml

# Export as environment variables
export DB_PASSWORD=$(sops --decrypt --extract '["database"]["password"]' secrets.yaml)


# ── VERIFY ───────────────────────────────────────────────────────

# Check if a file was encrypted with SOPS (and by whom)
sops filestatus secrets.yaml

# Show which keys can decrypt this file
sops --decrypt --show-master-keys secrets.yaml
```

---

## The Edit Workflow (Day-to-Day)

The most common operation: edit an encrypted file.

```bash
# Open the encrypted file in your editor — SOPS decrypts it first
sops secrets.yaml

# SOPS:
# 1. Decrypts the file to a temp file in /tmp
# 2. Opens your editor (uses $EDITOR env var, defaults to vim)
# 3. You see the PLAINTEXT and edit normally
# 4. When you save and close:
#    - SOPS re-encrypts all values
#    - Writes back to secrets.yaml (encrypted)
#    - Deletes the temp file
# 5. You commit secrets.yaml (encrypted) to git
```

**Setting your preferred editor:**

```bash
# In your ~/.bashrc or ~/.zshrc
export EDITOR=nano    # or vim, code, micro, etc.
```

---

## Using Decrypted Values in Scripts

```bash
# Option 1: Decrypt to environment variables (using YAML parsing)
eval $(sops --decrypt secrets.yaml | python3 -c "
import sys, yaml
data = yaml.safe_load(sys.stdin)
print(f'export DB_PASSWORD=\"{data[\"database\"][\"password\"]}\"')
print(f'export JWT_SECRET=\"{data[\"jwt\"][\"secret\"]}\"')
")

# Option 2: Direct extract
export DB_PASSWORD=$(sops -d --extract '["database"]["password"]' secrets.yaml)
export JWT_SECRET=$(sops -d --extract '["jwt"]["secret"]' secrets.yaml)

# Option 3: Let SOPS exec the command in a decrypted environment
# (SOPS decrypts the file as env vars and runs the command)
sops exec-env secrets.yaml 'node src/server.js'

# Option 4: For .env format files
sops -d secrets.env > /tmp/secrets.env && source /tmp/secrets.env && rm /tmp/secrets.env
```

---

## Git Integration — What to Commit

```bash
# What goes in git:
git add secrets.yaml         # encrypted file ✓

# What NEVER goes in git:
# - Decrypted secrets files
# - Your age private key (~/.config/sops/age/keys.txt)

# Add to .gitignore:
echo "*.plaintext.yaml" >> .gitignore
echo "secrets.dec.yaml" >> .gitignore
# Note: keys.txt is in ~/.config, not in the repo — it won't be committed unless you copy it here
```

---

## Verifying the Encryption

```bash
# The file in git is encrypted — verify:
cat secrets.yaml | grep password
# database.password: ENC[AES256_GCM,data:c3VwZXJTZWNyZXQxMjM=,...]

# Only you (with your private key) can decrypt:
sops -d secrets.yaml | grep password
# password: superSecret123

# If someone without the key tries:
sops -d secrets.yaml
# Error: Failed to call the authentication or authorization service.
# Or: Failed to decrypt key.
```

---

## Common Misunderstanding: "I should decrypt to a file first, then read that file"

**The misunderstanding:**
```bash
# ❌ People do this:
sops -d secrets.yaml > /tmp/secrets-plain.yaml
node -r /tmp/secrets-plain.yaml src/app.js
```

**Why it's risky:** The decrypted file exists on disk. If the process crashes, the shell exits unexpectedly, or the cleanup step fails — the plaintext secrets sit on disk unencrypted.

**Better approaches:**
```bash
# ✅ Pipe directly (never writes to disk)
sops -d secrets.yaml | yq '.database.password'

# ✅ Use sops exec-env (injects as env vars, never touches disk)
sops exec-env secrets.yaml 'node src/app.js'

# ✅ If you must write to disk, use tmpfs and clean up
sops -d secrets.yaml > /dev/shm/secrets.yaml   # /dev/shm is RAM, not disk
# ... use it ...
rm /dev/shm/secrets.yaml
```

→ Continue to: `02-age-encryption.md`
