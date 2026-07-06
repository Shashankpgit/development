# SOPS — 02: age Encryption — Keys, Teams, and Sharing

> **Last updated:** July 3, 2026
> **Covers:** age key management, sharing secrets with teammates, team key files, multiple recipients

**20-minute read. How to use SOPS with age for a team of developers.**

---

## How age Works in SOPS

age is the simplest SOPS backend. Each person or system has:
- A **private key**: stays on your machine, decrypts files
- A **public key**: share this, used by others to encrypt files FOR you

```
Developer A                         Developer B
  private key: AGE-SECRET-KEY-1...    private key: AGE-SECRET-KEY-1...
  public key:  age1abc...             public key:  age1xyz...

Team's secrets.yaml (in git):
  sops:
    age:
      - recipient: age1abc...    ← Developer A can decrypt
        enc: ...
      - recipient: age1xyz...    ← Developer B can decrypt
        enc: ...

Both developers can decrypt the same file using their own private keys.
```

---

## Single Developer Setup

```bash
# Generate your key (one time)
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# Your keys.txt contains:
# # created: 2026-07-03T10:00:00Z
# # public key: age1ql3z7hjy...
# AGE-SECRET-KEY-1QJJF7XQ6V...

# SOPS automatically finds keys in this location
# Or set explicitly:
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

---

## Multiple Recipients — Adding a Teammate

When a team needs to share a secrets file, ALL members' public keys go into the file. Each person can then decrypt it independently using their own private key.

```bash
# Developer A creates a secrets file for both A and B
DEVELOPER_A_PUBLIC_KEY="age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
DEVELOPER_B_PUBLIC_KEY="age1xyz789..."

sops --age "${DEVELOPER_A_PUBLIC_KEY},${DEVELOPER_B_PUBLIC_KEY}" \
     --encrypt --in-place secrets.yaml
```

The file now has TWO encrypted DEK blocks — one for A, one for B. Either can decrypt.

---

## The `.sops.yaml` Config File — Don't Specify Keys Every Time

Passing `--age` flags every time is tedious. Instead, create a `.sops.yaml` in your project root:

```yaml
# .sops.yaml — commit this file to git
creation_rules:
  - path_regex: .*\.yaml$        # apply to all YAML files
    age: >-
      age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p,
      age1xyz789abc123def456ghi7,
      age1ci-machine-key-here
```

Now you just run:

```bash
sops secrets.yaml    # automatically uses keys from .sops.yaml
```

No `--age` flag needed. SOPS reads `.sops.yaml` automatically.

---

## Team Key Management — The Pattern

The recommended pattern for a team:

```
project/
  .sops.yaml          ← lists all team members' public keys (commit this)
  secrets/
    production.yaml   ← encrypted secrets (commit this)
    staging.yaml      ← encrypted secrets (commit this)
    development.yaml  ← encrypted secrets (commit this)
  
team-keys/
  README.md           ← instructions for new team members
  keys.txt            ← ALL team members' PUBLIC keys (commit this)
                         (only public keys — never private keys)
```

```yaml
# .sops.yaml
creation_rules:
  # Development secrets — all devs + CI can decrypt
  - path_regex: secrets/development\.yaml$
    age: >-
      age1shashank...,
      age1developer2...,
      age1developer3...,
      age1ci-machine...

  # Staging — devs + CI can decrypt  
  - path_regex: secrets/staging\.yaml$
    age: >-
      age1shashank...,
      age1developer2...,
      age1ci-machine...

  # Production — only tech leads + CI can decrypt
  - path_regex: secrets/production\.yaml$
    age: >-
      age1shashank...,
      age1ci-machine-prod...
```

```markdown
# team-keys/README.md

## Team Public Keys
These are the AGE public keys for each team member.
Add your public key here when you join the team.
Your PRIVATE key stays on your machine — never share it.

| Name       | Public Key              |
|------------|------------------------|
| Shashank   | age1ql3z7hjy54pw3...   |
| Developer2 | age1xyz789abc123...    |
| CI Machine | age1ci789def456...     |
```

---

## Onboarding a New Developer

When a new developer joins:

```bash
# Step 1: New developer generates their key
age-keygen -o ~/.config/sops/age/keys.txt

# Step 2: New developer shares their PUBLIC key
cat ~/.config/sops/age/keys.txt | grep "public key"
# → sends "age1newdev789..." to the team

# Step 3: Existing team member adds the key to .sops.yaml
# Edit .sops.yaml, add the new public key to all relevant rules

# Step 4: Re-encrypt all secrets files with the new key added
# (SOPS updates the DEK to include the new recipient)
sops updatekeys secrets/development.yaml
sops updatekeys secrets/staging.yaml
# Production: only if the new dev needs production access

# Step 5: Commit and push .sops.yaml changes
git add .sops.yaml
git commit -m "chore(sops): add developer5 age key"
git push

# Step 6: New developer can now decrypt
sops -d secrets/development.yaml   # works with their private key
```

---

## Removing a Developer (Offboarding)

When a developer leaves:

```bash
# Step 1: Remove their public key from .sops.yaml
# Edit .sops.yaml, remove their age1xxx... key

# Step 2: Re-encrypt ALL secrets files WITHOUT their key
sops updatekeys secrets/development.yaml
sops updatekeys secrets/staging.yaml
sops updatekeys secrets/production.yaml

# Step 3: Commit and push
git add .sops.yaml
git commit -m "chore(sops): remove developer2 age key (offboarding)"
git push

# Result: Developer2's private key can no longer decrypt the current files
# Old git commits still have old encrypted versions, but those use old secrets
# which should also be rotated
```

**Important:** Removing the key doesn't invalidate old encrypted files in git history. The departing developer still has the private key and can decrypt old versions. This is why you should also rotate the actual secret values when someone leaves.

---

## The CI/CD Machine Key

Your CI/CD pipeline also needs to decrypt secrets. You need a "machine key" — an age key used by CI, stored as a CI/CD secret.

```bash
# Generate a dedicated CI key (not your personal key)
age-keygen -o /tmp/ci-key.txt
cat /tmp/ci-key.txt
# # public key: age1ci789def456...
# AGE-SECRET-KEY-1CI...

# Add the CI public key to .sops.yaml (see above)

# Store the PRIVATE key in GitHub Actions secrets:
# GitHub → Repository → Settings → Secrets → Actions
# Name: SOPS_AGE_KEY
# Value: (paste the AGE-SECRET-KEY-1CI... line)

# Delete the local temp file
rm /tmp/ci-key.txt
```

In GitHub Actions:

```yaml
- name: Decrypt secrets
  env:
    SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
  run: |
    # SOPS picks up SOPS_AGE_KEY from env automatically
    sops -d secrets/staging.yaml > /tmp/secrets.yaml
    # Use the decrypted file...
```

---

## Multiple Key Files

Sometimes you need different keys for different contexts (personal, work, legacy):

```bash
# ~/.config/sops/age/keys.txt can have MULTIPLE keys
# SOPS tries each key until one works
cat ~/.config/sops/age/keys.txt
# # created: 2026-01-01T00:00:00Z
# # public key: age1personal...
# AGE-SECRET-KEY-1PERSONAL...
# # created: 2026-06-01T00:00:00Z
# # public key: age1work...
# AGE-SECRET-KEY-1WORK...
```

Or point to a different key file:

```bash
SOPS_AGE_KEY_FILE=/path/to/other/keys.txt sops -d secrets.yaml
```

---

## Verifying Who Can Decrypt a File

```bash
# See which recipients are configured for this file
sops --decrypt --show-master-keys secrets/production.yaml

# Output shows all recipients:
# age recipient: age1shashank...
# age recipient: age1ci-machine...
# (no developer2 — they don't have production access)
```

---

## Backup Your Private Key

Your private key is the only thing that lets you decrypt files encrypted for you. If you lose it:
- You lose access to all files encrypted for you
- You need to ask a teammate to re-encrypt files without you, then add your new key

```bash
# Back up your private key somewhere SECURE:
# - Password manager (1Password, Bitwarden)
# - Encrypted external drive
# - Another machine you control

# The key is just text — copy-paste it:
cat ~/.config/sops/age/keys.txt
# AGE-SECRET-KEY-1QJJF7XQ6V...

# Store the entire output of this file securely
```

---

## age vs PGP

SOPS has long supported PGP (GPG). age is the modern replacement:

| | age | PGP/GPG |
|--|-----|---------|
| Key generation | Simple (one command) | Complex (key type, expiry, subkeys) |
| Key distribution | Share a one-line public key | Keyservers, web of trust |
| Key format | Short, readable | Long, complex |
| Algorithm | X25519 + ChaCha20 | RSA/DSA + symmetric cipher |
| Software | Tiny, focused | GPG (complex, many options) |
| Status | Modern, actively developed | Legacy, but universal |

**Use age** unless you already have a PGP infrastructure or need to work with legacy systems that use GPG.

---

## Common Misunderstanding: "I should commit my private key to the repo for CI"

**The misunderstanding:** "I'll commit the age private key file to the repo so CI can find it."

**What happens:**
```
Your private key is now in git.
Anyone who can read the repo (all devs, GitHub admins, anyone who forks it)
can decrypt ALL your secrets.
This completely defeats the purpose of SOPS.
```

**The correct approach:**
- Private keys go in CI secrets (GitHub Secrets, GitLab CI Variables, etc.)
- The CI pipeline sets `SOPS_AGE_KEY` environment variable at runtime
- The private key never touches the filesystem or git history

→ Continue to: `03-cloud-kms.md`
