# SOPS — Complete Guide

> **Last updated:** July 3, 2026
> **Version covered:** SOPS v3.9.0, age v1.2.0
> **Level:** DevOps Engineer (Beginner to Production-Ready)

---

## What Is SOPS?

SOPS (Secrets OPerationS) by Mozilla/CNCF lets you **commit encrypted secret files to git safely**. It encrypts the values in YAML/JSON/.env files while keeping the structure readable — so PR diffs show what changed without exposing the secrets themselves.

---

## Reading Order

Read these in order — each file builds on the previous.

| File | What You Learn | Time |
|------|---------------|------|
| [00 — Mental Model](00-mental-model.md) | The secrets-in-git problem, how SOPS solves it, when to use it | 20 min |
| [01 — Installation and Setup](01-installation-and-setup.md) | Install SOPS + age, encrypt your first file, understand the file format | 20 min |
| [02 — age Encryption](02-age-encryption.md) | Team key management, onboarding/offboarding, CI machine keys | 20 min |
| [03 — Cloud KMS](03-cloud-kms.md) | AWS KMS + IRSA, GCP KMS, Azure Key Vault, audit logging | 20 min |
| [04 — .sops.yaml Config](04-sops-config-file.md) | Creation rules, path_regex, encrypted_regex, key groups | 20 min |
| [05 — File Types](05-file-types-and-partial-encryption.md) | YAML, JSON, .env, binary — how each works, partial encryption | 20 min |
| [06 — Kubernetes and Helm](06-kubernetes-and-helm.md) | helm-secrets plugin, ArgoCD + SOPS, sops-secrets-operator | 20 min |
| [07 — CI/CD Integration](07-ci-cd-integration.md) | GitHub Actions + AWS KMS OIDC, GitLab CI, age key in CI | 20 min |
| [08 — Real-World Patterns](08-real-world-patterns.md) | Multi-env setup, key rotation, break-glass, migration, troubleshooting | 20 min |

---

## The 3-Sentence Summary

SOPS encrypts the VALUES in your secrets files (YAML, JSON, .env) while leaving the KEYS visible — so you can safely commit the encrypted file to git and reviewers can see what changed without seeing the values. Your team members each have an age private key on their laptop; the file's SOPS metadata block lists everyone's public key, so anyone on the team can decrypt independently. In production, Kubernetes pods decrypt via AWS KMS + IRSA (no stored credentials), CI/CD pipelines decrypt via OIDC role assumption, and the `helm-secrets` plugin decrypts at deploy time so Helm templates always see plaintext values.

---

## Quick Command Reference

```bash
# ── INSTALL ────────────────────────────────────────────────────────
brew install sops age                     # macOS
# Linux (Ubuntu/Debian x86_64):
# curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops_3.9.0_amd64.deb
# sudo dpkg -i sops_3.9.0_amd64.deb && sudo apt install age
# Linux (Amazon Linux/RHEL x86_64):
# curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops-3.9.0-1.x86_64.rpm
# sudo rpm -ivh sops-3.9.0-1.x86_64.rpm
# See 01-installation-and-setup.md for ARM64 and other Linux variants
age-keygen -o ~/.config/sops/age/keys.txt # generate your age key

# ── ENCRYPT / DECRYPT ─────────────────────────────────────────────
sops secrets/production.yaml             # edit an encrypted file
sops -d secrets/production.yaml          # decrypt to stdout
sops -d secrets/production.yaml > /tmp/plain.yaml  # decrypt to file (careful!)
sops -d --extract '["database"]["password"]' secrets.yaml  # get one value

# ── CREATE / ENCRYPT ──────────────────────────────────────────────
sops -e -i secrets.yaml                  # encrypt in-place (needs .sops.yaml)
sops --age age1pub... -e -i secrets.yaml # encrypt with specific key

# ── UPDATE KEYS ───────────────────────────────────────────────────
sops updatekeys secrets/production.yaml  # re-encrypt with current .sops.yaml keys

# ── EXEC ENV ──────────────────────────────────────────────────────
sops exec-env secrets.yaml 'node server.js'  # decrypt as env vars, run command

# ── DEBUG ─────────────────────────────────────────────────────────
sops --show-master-keys -d secrets.yaml  # show who can decrypt this file
sops filestatus secrets.yaml             # check if file is encrypted
```

---

## Key Configuration Quick Pick

```
Small team, simple setup?
  → age (file 02)
  → .sops.yaml with all team public keys
  → Store CI private key in GitHub Secrets

AWS org, production system?
  → AWS KMS (file 03)
  → IRSA for Kubernetes pods
  → OIDC for GitHub Actions (no stored credentials)
  → age as break-glass backup

Multi-cloud or agnostic?
  → age for developers
  → Cloud KMS for CI/CD in each environment
  → Mix both in .sops.yaml (file 04)
```

---

## The Full Flow: Secret → Kubernetes → Pod

```
Developer edits secret (sops secrets/production.yaml)
  ↓ SOPS re-encrypts on save
Git commit: encrypted file
  ↓ git push → PR → merge to main
GitHub Actions (OIDC → IAM role → KMS decrypt permission)
  ↓ helm-secrets decrypts values.secrets.production.yaml
Helm renders Kubernetes Secret with plaintext values
  ↓ kubectl apply
Kubernetes Secret in etcd (optionally encrypted at rest)
  ↓ mounted as env vars
Pod reads DATABASE_PASSWORD, JWT_SECRET, STRIPE_KEY
```

---

## Troubleshooting Quick Reference

| Error | Cause | Fix |
|-------|-------|-----|
| `could not decrypt key` | Your key not in file recipients | Ask teammate to run `sops updatekeys` with your key added |
| `MAC verification failed` | File tampered or merge conflict corrupted it | Re-decrypt/re-encrypt from a clean version |
| `kms: failed to create session` | No AWS credentials or wrong region | Check `aws sts get-caller-identity` |
| `no match in creation_rules` | File path not covered by .sops.yaml | Add a catch-all rule or add path to existing rule |
| Helm deploys old secrets | helm-secrets not picking up encrypted file | Ensure file has `.yaml` extension and `sops:` block exists |
| ArgoCD sync fails on decrypt | ArgoCD doesn't have the decryption key | Verify age key secret is mounted in argocd repo-server |

---

## References

- SOPS GitHub: https://github.com/getsops/sops
- SOPS Documentation: https://getsops.io/docs/
- age GitHub: https://github.com/FiloSottile/age
- helm-secrets: https://github.com/jkroepke/helm-secrets
- ArgoCD SOPS plugin: https://argo-cd.readthedocs.io/en/stable/operator-manual/config-management-plugins/
- sops-secrets-operator: https://github.com/isindir/sops-secrets-operator

---

## Data Freshness

- SOPS version: **v3.9.0** (latest stable, July 2026)
- age version: **v1.2.0** (latest stable, July 2026)
- helm-secrets version: **v4.6.1** (July 2026)
- AWS OIDC + GitHub Actions: verified against current GitHub Actions and AWS documentation
