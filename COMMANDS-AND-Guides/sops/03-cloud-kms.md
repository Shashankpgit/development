# SOPS — 03: Cloud KMS Backends — AWS, GCP, Azure

> **Last updated:** July 3, 2026
> **Covers:** AWS KMS + IRSA, GCP KMS, Azure Key Vault — when to use cloud KMS, IAM-based access control

**20-minute read. Cloud KMS gives you IAM-based access instead of key files — the production-grade approach.**

---

## Why Cloud KMS Over age?

age is simple and works well for small teams. Cloud KMS adds something age can't:

```
age:
  Access = who has the private key file
  Revoke = re-encrypt all files, hope old key files are deleted
  Audit  = no log of who decrypted what or when

AWS KMS:
  Access = who has IAM permissions (user, role, service account)
  Revoke = remove IAM permission → immediately can't decrypt
  Audit  = CloudTrail logs EVERY decrypt call (who, when, what key, from where)
```

For a production system in an organization:
- A new developer gets AWS access → automatically can decrypt if they have the right IAM role
- A developer leaves → revoke their AWS access → immediately lose decrypt ability
- Compliance audit: "Show me everyone who accessed the production database password in the last 90 days" → CloudTrail has every answer

---

## AWS KMS Setup

### Step 1: Create a KMS Key

```bash
# Create a symmetric KMS key
aws kms create-key \
  --description "SOPS encryption key for vault-app" \
  --key-usage ENCRYPT_DECRYPT \
  --origin AWS_KMS \
  --region ap-south-1

# Output includes:
# "KeyMetadata": {
#   "KeyId": "12345678-1234-1234-1234-123456789012",
#   "Arn": "arn:aws:kms:ap-south-1:123456789012:key/12345678-1234-1234-1234-123456789012"
# }

# Add a user-friendly alias
aws kms create-alias \
  --alias-name alias/vault-app-sops \
  --target-key-id 12345678-1234-1234-1234-123456789012 \
  --region ap-south-1
```

### Step 2: Create IAM Policy for SOPS

```json
// iam-policy-sops-decrypt.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:ap-south-1:123456789012:key/12345678-..."
    }
  ]
}

// iam-policy-sops-encrypt.json (for creating/editing files)
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:ap-south-1:123456789012:key/12345678-..."
    }
  ]
}
```

**Who needs which permissions:**
- **Developers editing secrets:** Encrypt + Decrypt + GenerateDataKey
- **Applications/CI reading secrets:** Decrypt only
- **Key administrators:** Full KMS admin actions

### Step 3: Encrypt with KMS

```bash
# Encrypt a file using KMS ARN
sops --kms arn:aws:kms:ap-south-1:123456789012:key/12345678-1234-1234-1234-123456789012 \
     --encrypt --in-place secrets.yaml

# Or using the alias (easier to remember)
sops --kms arn:aws:kms:ap-south-1:123456789012:alias/vault-app-sops \
     --encrypt --in-place secrets.yaml
```

Better: put the KMS ARN in `.sops.yaml`:

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    kms: arn:aws:kms:ap-south-1:123456789012:alias/vault-app-sops
```

Now just run `sops secrets/production.yaml` — no flags needed.

### Step 4: Decrypt (Any Machine with AWS Credentials + IAM Permission)

```bash
# Your local machine — uses your ~/.aws/credentials or IAM role
sops -d secrets/production.yaml

# CI/CD pipeline — uses the EC2/EKS instance role (IRSA)
sops -d secrets/production.yaml

# No key file needed! Access is via IAM permissions
```

---

## IRSA — IAM Roles for Service Accounts (Kubernetes + EKS)

In Kubernetes, you don't want AWS credentials in environment variables. Use IRSA: your Kubernetes pods assume an IAM role automatically, no credentials needed.

### Setup IRSA for a Pod that Decrypts SOPS

```bash
# Step 1: Get your cluster's OIDC provider URL
aws eks describe-cluster --name vault-cluster \
  --query "cluster.identity.oidc.issuer" --output text
# https://oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE1234

# Step 2: Create IAM role with trust policy
aws iam create-role \
  --role-name vault-app-sops-decrypt \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE1234"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE1234:sub":
            "system:serviceaccount:production:vault-api"
        }
      }
    }]
  }'

# Step 3: Attach the decrypt-only policy
aws iam attach-role-policy \
  --role-name vault-app-sops-decrypt \
  --policy-arn arn:aws:iam::123456789012:policy/sops-decrypt-only
```

```yaml
# Kubernetes ServiceAccount annotated with the IAM role
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-api
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/vault-app-sops-decrypt
```

Now any pod using the `vault-api` ServiceAccount can run `sops -d` without any AWS credentials configured. The pod automatically assumes the IAM role.

---

## Multi-Region KMS Keys

For high-availability, replicate your KMS key to multiple regions:

```bash
# Create a multi-region primary key
aws kms create-key \
  --description "SOPS primary key" \
  --multi-region \
  --region ap-south-1

# Replicate to another region
aws kms replicate-key \
  --key-id arn:aws:kms:ap-south-1:123456789012:key/12345678-... \
  --replica-region ap-southeast-1 \
  --region ap-south-1
```

In `.sops.yaml`, list multiple KMS ARNs:

```yaml
creation_rules:
  - path_regex: secrets/production\.yaml$
    kms: >-
      arn:aws:kms:ap-south-1:123456789012:alias/vault-app-sops,
      arn:aws:kms:ap-southeast-1:123456789012:alias/vault-app-sops
```

If one region is unavailable, SOPS falls back to the other.

---

## GCP KMS Setup

```bash
# Enable the Cloud KMS API
gcloud services enable cloudkms.googleapis.com

# Create a key ring
gcloud kms keyrings create vault-app-sops \
  --location global

# Create a key in the ring
gcloud kms keys create sops-key \
  --location global \
  --keyring vault-app-sops \
  --purpose encryption

# Full resource name:
# projects/my-project/locations/global/keyRings/vault-app-sops/cryptoKeys/sops-key
```

Grant IAM permissions:

```bash
# Grant decrypt permission to a service account
gcloud kms keys add-iam-policy-binding sops-key \
  --location global \
  --keyring vault-app-sops \
  --member serviceAccount:vault-app@my-project.iam.gserviceaccount.com \
  --role roles/cloudkms.cryptoKeyDecrypter

# Grant encrypt+decrypt to developers
gcloud kms keys add-iam-policy-binding sops-key \
  --location global \
  --keyring vault-app-sops \
  --member user:shashank@company.com \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter
```

In `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    gcp_kms: projects/my-project/locations/global/keyRings/vault-app-sops/cryptoKeys/sops-key
```

```bash
# Encrypt (GCP credentials in GOOGLE_APPLICATION_CREDENTIALS or gcloud auth)
sops secrets/production.yaml

# Decrypt (Workload Identity in GKE, or service account key locally)
sops -d secrets/production.yaml
```

---

## Azure Key Vault Setup

```bash
# Create a Key Vault
az keyvault create \
  --name vault-app-sops \
  --resource-group vault-rg \
  --location eastus

# Create a key
az keyvault key create \
  --vault-name vault-app-sops \
  --name sops-key \
  --kty RSA-HSM \
  --size 2048

# Grant access to a developer
az keyvault set-policy \
  --name vault-app-sops \
  --upn shashank@company.com \
  --key-permissions encrypt decrypt wrapKey unwrapKey get list

# Grant access to a service principal (for CI/CD)
az keyvault set-policy \
  --name vault-app-sops \
  --spn <service-principal-object-id> \
  --key-permissions decrypt unwrapKey get
```

In `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    azure_kv: https://vault-app-sops.vault.azure.net/keys/sops-key/version-id
```

---

## Combining Cloud KMS with age

Best practice for teams: use BOTH cloud KMS (for CI/CD + Kubernetes) AND age (for developer laptops):

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/production\.yaml$
    # Kubernetes pods use AWS KMS via IRSA
    kms: arn:aws:kms:ap-south-1:123456789012:alias/vault-app-sops-prod
    # Tech leads can decrypt on their laptops with age keys
    age: >-
      age1shashank...,
      age1techlead2...

  - path_regex: secrets/staging\.yaml$
    kms: arn:aws:kms:ap-south-1:123456789012:alias/vault-app-sops-staging
    age: >-
      age1shashank...,
      age1developer2...,
      age1developer3...

  - path_regex: secrets/development\.yaml$
    # Development: age only, no need for KMS
    age: >-
      age1shashank...,
      age1developer2...,
      age1developer3...,
      age1developer4...
```

```
Outcome:
  Production secrets: Kubernetes pods decrypt via IRSA, tech leads via age key
  Staging secrets: CI pipeline + all devs can decrypt
  Development secrets: All devs can decrypt, no AWS permissions needed
```

---

## KMS Key Policy (AWS) — Fine-Grained Control

The KMS key policy is separate from IAM policies and provides an additional layer:

```json
{
  "Version": "2012-10-17",
  "Id": "vault-app-sops-key-policy",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow developers to use the key",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::123456789012:user/shashank",
          "arn:aws:iam::123456789012:user/developer2"
        ]
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow CI/CD to decrypt only",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/github-actions-role"
      },
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## Auditing: Who Decrypted What?

With AWS KMS, every decrypt call is logged in CloudTrail:

```bash
# Find all decrypt operations for your SOPS key in the last 24 hours
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=Decrypt \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
  | jq '.Events[] | select(.CloudTrailEvent | fromjson | .requestParameters.keyId | test("vault-app-sops")) 
    | {time: .EventTime, user: .Username, source: .CloudTrailEvent | fromjson | .sourceIPAddress}'
```

Output shows:
```json
{"time": "2026-07-03T14:22:31", "user": "shashank", "source": "203.0.113.1"}
{"time": "2026-07-03T15:01:45", "user": "github-actions-runner", "source": "140.82.x.x"}
```

This level of audit logging is not possible with age (a file on disk has no call log).

---

## Common Misunderstanding: "I should use a different KMS key for every secret file"

**The misunderstanding:** "For better security, each file should have its own KMS key."

**The reality:** SOPS already does key-per-file encryption internally (the DEK). The KMS key you provide is the Key Encryption Key (KEK) — it encrypts the DEK.

Using one KMS key for all your SOPS files is fine and normal. Use different keys only when you have different access control requirements:

```
One key per environment is a reasonable split:
  alias/sops-production  → only tech leads + prod CI can use
  alias/sops-staging     → all developers + CI can use
  alias/sops-development → all developers can use

One key per file = unnecessary complexity.
```

→ Continue to: `04-sops-config-file.md`
