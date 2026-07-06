# SOPS — 07: CI/CD Integration

> **Last updated:** July 3, 2026
> **Covers:** GitHub Actions + AWS KMS (OIDC), GitHub Actions + age key, GitLab CI, key rotation in pipelines

**20-minute read. Your CI/CD pipeline needs to decrypt SOPS files — here's how to do it securely.**

---

## The CI/CD Secrets Challenge

Your pipeline needs to:
1. Decrypt SOPS-encrypted files to get the real secrets
2. Use those secrets for deployment, tests, etc.

The pipeline is NOT a human — it can't enter a password or look up a key. It needs credentials stored somewhere secure.

**Two approaches:**
- **age key in CI secret:** Store the private key as a CI environment variable (simple)
- **Cloud KMS via OIDC:** Pipeline assumes an IAM role with decrypt permission (no stored credentials)

---

## Approach 1: age Key as a CI Secret (Simpler)

Generate a dedicated CI age key, store the private key in GitHub Secrets.

### Setup (One Time)

```bash
# Generate a CI-specific age key
age-keygen -o /tmp/ci-key.txt
cat /tmp/ci-key.txt

# Output:
# # created: 2026-07-03
# # public key: age1ci789abc...
# AGE-SECRET-KEY-1CI...

# 1. Add the public key to .sops.yaml (commit this)
# 2. Re-encrypt secrets with the new recipient:
sops updatekeys secrets/*.yaml

# 3. Add the PRIVATE key to GitHub Secrets:
#    GitHub → Repo → Settings → Secrets and variables → Actions
#    Name: SOPS_AGE_KEY
#    Value: (the AGE-SECRET-KEY-1CI... line — just this one line)

# 4. Delete the temp file
rm /tmp/ci-key.txt
```

### GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Install SOPS
      run: |
        curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64
        chmod +x sops-v3.9.0.linux.amd64
        sudo mv sops-v3.9.0.linux.amd64 /usr/local/bin/sops
    
    - name: Decrypt secrets
      env:
        SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}    # ← the private key
      run: |
        # SOPS picks up the key from SOPS_AGE_KEY env var automatically
        sops -d secrets/production.yaml > /tmp/secrets.yaml
    
    - name: Deploy
      env:
        SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
      run: |
        # Use helm-secrets which decrypts inline
        helm secrets upgrade vault-app ./helm/vault-api/ \
          --namespace production \
          -f helm/vault-api/values.yaml \
          -f helm/vault-api/values.secrets.yaml
```

**Security of this approach:**
- The private key is in GitHub Secrets (encrypted at rest, never shown in logs)
- The key is only exposed as an environment variable during the job
- If someone clones the repo, they don't get the key
- If GitHub is compromised, the key could be extracted (same risk as any CI secret)

---

## Approach 2: AWS KMS + GitHub Actions OIDC (Production-Grade)

No stored credentials. The pipeline assumes an IAM role via OpenID Connect. This is the most secure approach.

### Setup (One Time)

```bash
# GitHub Actions automatically exposes an OIDC token for IAM role assumption
# You configure which GitHub repo/workflow can assume which IAM role

# 1. Set up GitHub OIDC provider in AWS (one-time per AWS account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2. Create IAM role with trust policy for GitHub Actions
aws iam create-role \
  --role-name github-actions-sops-decrypt \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:your-org/vault-app:*"
        }
      }
    }]
  }'

# 3. Attach KMS decrypt policy
aws iam attach-role-policy \
  --role-name github-actions-sops-decrypt \
  --policy-arn arn:aws:iam::123456789012:policy/sops-decrypt-only
```

### GitHub Actions Workflow (OIDC + KMS)

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

permissions:
  id-token: write     # ← required for OIDC token generation
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS Credentials via OIDC
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::123456789012:role/github-actions-sops-decrypt
        aws-region: ap-south-1
        # No access keys — assumes role via OIDC token
    
    - name: Install SOPS and helm-secrets
      run: |
        curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64
        chmod +x sops-v3.9.0.linux.amd64
        sudo mv sops-v3.9.0.linux.amd64 /usr/local/bin/sops
        helm plugin install https://github.com/jkroepke/helm-secrets
    
    - name: Decrypt and verify (optional check)
      run: sops -d secrets/production.yaml > /dev/null && echo "Decryption successful"
    
    - name: Deploy with helm-secrets
      run: |
        helm secrets upgrade vault-app ./helm/vault-api/ \
          --namespace production \
          --install \
          --atomic \
          -f helm/vault-api/values.yaml \
          -f helm/vault-api/values.secrets.production.yaml
```

**Why this is better than stored credentials:**
- No private key in GitHub Secrets
- AWS CloudTrail logs every decrypt call made by this pipeline
- If the GitHub Actions workflow is modified, the trust policy can be tightened to specific branches/tags
- Token is short-lived (~15 minutes), generated fresh each run

---

## Environment-Specific Deployments

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main, develop]
  release:
    types: [published]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    # Determine environment based on trigger
    env:
      ENVIRONMENT: ${{ 
        github.event_name == 'release' && 'production' || 
        github.ref == 'refs/heads/main' && 'staging' || 
        'development' 
      }}
    
    permissions:
      id-token: write
      contents: read
    
    # Use GitHub Environments for protection rules
    environment: ${{ env.ENVIRONMENT }}
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS (role depends on environment)
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ 
          env.ENVIRONMENT == 'production' && 
          'arn:aws:iam::123456789012:role/github-actions-prod' || 
          'arn:aws:iam::123456789012:role/github-actions-staging' 
        }}
        aws-region: ap-south-1
    
    - name: Deploy
      run: |
        helm secrets upgrade vault-app ./helm/vault-api/ \
          --namespace ${{ env.ENVIRONMENT }} \
          -f helm/vault-api/values.yaml \
          -f helm/vault-api/values.secrets.${{ env.ENVIRONMENT }}.yaml
```

---

## GitLab CI Integration

```yaml
# .gitlab-ci.yml
variables:
  SOPS_AGE_KEY: $CI_SOPS_AGE_KEY    # stored in GitLab CI/CD Variables

stages:
  - decrypt
  - deploy

decrypt-secrets:
  stage: decrypt
  image: debian:bookworm
  before_script:
    - apt-get install -y curl
    - curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64
    - chmod +x sops-v3.9.0.linux.amd64
    - mv sops-v3.9.0.linux.amd64 /usr/local/bin/sops
  script:
    - sops -d secrets/$CI_ENVIRONMENT_NAME.yaml > /tmp/secrets.yaml
  artifacts:
    paths:
      - /tmp/secrets.yaml    # ⚠️ careful — this is decrypted!
    expire_in: 10 minutes    # auto-expire quickly

deploy:
  stage: deploy
  needs: [decrypt-secrets]
  script:
    - helm upgrade vault-app ./helm/ --values /tmp/secrets.yaml
  environment:
    name: production
    url: https://api.vault.example.com
```

**Better GitLab approach — inline decryption:**

```yaml
deploy:
  stage: deploy
  variables:
    SOPS_AGE_KEY: $CI_SOPS_AGE_KEY
  script:
    - |
      helm secrets upgrade vault-app ./helm/vault-api/ \
        -f helm/vault-api/values.yaml \
        -f helm/vault-api/values.secrets.production.yaml
```

---

## Running Tests with Decrypted Secrets

For integration tests that need real credentials:

```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests

on:
  pull_request:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::123456789012:role/github-actions-test
        aws-region: ap-south-1
    
    - uses: actions/setup-node@v4
      with:
        node-version: 20
    
    - run: npm ci
    
    - name: Run integration tests with decrypted secrets
      run: |
        # sops exec-env decrypts and injects as environment variables
        # The secrets are never written to disk
        sops exec-env secrets/staging.yaml 'npm run test:integration'
```

`sops exec-env` is perfect for tests — decrypts secrets, runs the command with them as env vars, cleans up. Nothing touches disk.

---

## Common Misunderstanding: "CI needs all the secrets, so it should have admin KMS access"

**The misunderstanding:** "The CI user needs Encrypt + Decrypt + GenerateDataKey permissions because it might need to create new encrypted files."

**The reality:** CI/CD pipelines should have **Decrypt-only** permissions. Only developers (humans creating/editing secret files) need Encrypt + GenerateDataKey.

```
Developers (local machine):
  kms:Encrypt, kms:Decrypt, kms:GenerateDataKey, kms:DescribeKey

CI/CD pipelines:
  kms:Decrypt, kms:DescribeKey   ← minimum needed to sops -d

Applications (running in Kubernetes):
  kms:Decrypt, kms:DescribeKey   ← same as CI
```

If your CI pipeline has Encrypt permissions and it's compromised, an attacker can encrypt their own malicious values into your secrets files. With Decrypt-only, the worst case is they can READ current secrets — bad, but not as bad as writing to them.

Principle: grant the minimum permissions needed for the job.

→ Continue to: `08-real-world-patterns.md`
