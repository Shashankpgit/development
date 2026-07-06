# IAM — 03: Roles Deep Dive

> **Last updated:** July 5, 2026
> **This is the most confusing part of IAM. Read every section carefully.**

---

## What Is a Role?

A **Role** is an IAM identity that **does not belong to a specific person**. Instead, it is **assumed temporarily** by whoever needs it.

A user has permanent credentials (password, access keys that don't change until you rotate them).

A role has **no permanent credentials**. When someone assumes a role, AWS generates temporary credentials on the spot — valid for 15 minutes to 12 hours, then they expire automatically.

### The Job Badge Analogy

Imagine a building with multiple departments:

- **User** = A permanent employee with their own badge
- **Role** = A visitor badge hanging by the front desk labeled "PLUMBER"
  - When the plumber arrives, they pick up the badge
  - Now they can access the maintenance rooms
  - When they leave, they drop the badge
  - The badge doesn't care WHO picks it up — it just grants access to whoever is wearing it

Similarly, an IAM Role doesn't care who assumes it — it grants the same permissions to whoever assumes it (as long as they're allowed to).

---

## The Two Policies a Role Has

This is where everyone gets confused. A role has TWO separate policy types, and they do completely different things:

```
┌────────────────────────────────────────────────────────────┐
│                        IAM Role                            │
│                                                            │
│  Trust Policy       → WHO is allowed to assume this role   │
│  (who can wear it)                                         │
│                                                            │
│  Permission Policy  → WHAT they can do after assuming it   │
│  (what the badge gives access to)                          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Trust Policy

The Trust Policy answers: **"Who is allowed to assume (pick up) this role?"**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Breaking this down:
- `Principal` → Who is trusted to assume this role
  - `"Service": "ec2.amazonaws.com"` → EC2 service (i.e., any EC2 instance)
  - `"Service": "lambda.amazonaws.com"` → Lambda functions
  - `"AWS": "arn:aws:iam::123456789012:user/shashank"` → A specific IAM user
  - `"AWS": "arn:aws:iam::999999999999:root"` → Entire other AWS account
- `Action` → Always `sts:AssumeRole` — this is how roles are assumed
- `Effect` → Always `Allow` in a trust policy (you're granting trust)

### Permission Policy

The Permission Policy answers: **"After assuming the role, what can they do?"**

This is a normal IAM policy — exactly what you learned in the previous file:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-app-bucket/*"
    }
  ]
}
```

---

## A Complete Example: EC2 Reading from S3

Scenario: You have an EC2 instance running your app. The app needs to read files from S3.

**Wrong approach (don't do this):**
```bash
# Storing access keys on the EC2 instance
# On the EC2 server:
aws configure
# AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key: wJalrXUtnFEMI...
```

Problems:
- Keys are stored in `~/.aws/credentials` on the server
- If someone hacks into the server, they get the keys
- Keys are long-lived — they work until you manually rotate them
- If you make 100 EC2 instances, you have 100 copies of those keys

**Right approach (using a role):**

Step 1: Create the role with a trust policy that allows EC2 to assume it:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

Step 2: Attach a permission policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::my-app-bucket",
      "arn:aws:s3:::my-app-bucket/*"
    ]
  }]
}
```

Step 3: Attach the role to the EC2 instance (via **Instance Profile** — explained next).

Step 4: Your app on EC2 calls S3 — AWS automatically provides temporary credentials:
```python
import boto3
# No credentials needed! The SDK finds them automatically
# from the instance metadata service
s3 = boto3.client('s3')
s3.get_object(Bucket='my-app-bucket', Key='config.json')
```

---

## What Is an Instance Profile?

When you attach a role to an EC2 instance, AWS uses an **Instance Profile** as the container.

You don't usually think about this — the AWS Console creates the instance profile automatically when you create a role for EC2. But you'll see the term in CLI output and Terraform.

```
Role         → The IAM identity with trust + permission policies
Instance Profile → The wrapper that lets EC2 use a role
              (one instance profile can hold one role)
```

```bash
# CLI: Create instance profile and add role to it
aws iam create-instance-profile --instance-profile-name my-ec2-profile
aws iam add-role-to-instance-profile \
  --instance-profile-name my-ec2-profile \
  --role-name my-ec2-s3-role

# Attach to a running EC2 instance
aws ec2 associate-iam-instance-profile \
  --instance-id i-1234567890abcdef0 \
  --iam-instance-profile Name=my-ec2-profile
```

**In the console:** When launching an EC2 instance, there's a field "IAM Instance Profile" — select your role there. The console handles the instance profile automatically.

---

## How the Temporary Credentials Work

When EC2 has a role attached, AWS automatically makes temporary credentials available via the **Instance Metadata Service (IMDS)**:

```bash
# Inside the EC2 instance:
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
# Returns: my-ec2-s3-role

curl http://169.254.169.254/latest/meta-data/iam/security-credentials/my-ec2-s3-role
# Returns:
# {
#   "AccessKeyId": "ASIAIOSFODNN7EXAMPLE",
#   "SecretAccessKey": "wJalrXUtnFEMI...",
#   "Token": "FwoGZXIv...",         ← Session token (required with temp creds)
#   "Expiration": "2026-07-05T14:30:00Z"  ← Expires in ~1 hour
# }
```

The AWS SDKs (boto3, AWS SDK for Node.js, etc.) automatically fetch from this URL and refresh before expiry. **You never see this happening** — the SDK handles it silently.

---

## Role Assumption by a User (Cross-Account or Elevated Permissions)

Users can also assume roles manually:

### Use case 1: Temporary elevated access

Developer normally has read-only permissions. For a deployment, they need to assume a "deploy role" with more permissions.

```bash
# Developer assumes the deploy role
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/DeployRole \
  --role-session-name "shashank-deployment-2026"

# Output:
# {
#   "Credentials": {
#     "AccessKeyId": "ASIAIOSFODNN7EXAMPLE",
#     "SecretAccessKey": "...",
#     "SessionToken": "...",
#     "Expiration": "2026-07-05T15:00:00Z"
#   }
# }

# Use the temporary credentials
export AWS_ACCESS_KEY_ID=ASIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...

# Now CLI commands use the deploy role's permissions
aws s3 sync ./dist s3://prod-bucket/
```

The trust policy on `DeployRole` must allow the developer to assume it:
```json
{
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::123456789012:user/shashank"
    },
    "Action": "sts:AssumeRole"
  }]
}
```

### Use case 2: Cross-account access

Your DevOps team is in Account A. The production environment is in Account B. You need to allow your team to manage resources in the production account without creating separate IAM users there.

**In Account B (production):** Create a role with a trust policy allowing Account A:
```json
{
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::ACCOUNT_A_ID:root"
    },
    "Action": "sts:AssumeRole"
  }]
}
```

**In Account A:** Create a policy allowing your DevOps team to assume that role:
```json
{
  "Statement": [{
    "Effect": "Allow",
    "Action": "sts:AssumeRole",
    "Resource": "arn:aws:iam::ACCOUNT_B_ID:role/ProdAccessRole"
  }]
}
```

Now from Account A, your engineers can: `aws sts assume-role --role-arn arn:aws:iam::ACCOUNT_B_ID:role/ProdAccessRole`

---

## Roles for AWS Services

Each AWS service that needs to act on your behalf gets a role. Examples:

| Service | What role it needs | Example trust principal |
|---------|-------------------|------------------------|
| EC2 | Read from S3, write to CloudWatch | `ec2.amazonaws.com` |
| Lambda | Read DynamoDB, write to SQS | `lambda.amazonaws.com` |
| ECS Task | Pull from ECR, read from Secrets Manager | `ecs-tasks.amazonaws.com` |
| CodePipeline | Deploy to EC2, update ECS | `codepipeline.amazonaws.com` |
| CloudFormation | Create any resource | `cloudformation.amazonaws.com` |

---

## Creating a Role (Console — Step by Step)

1. IAM → Roles → **Create role**
2. **Trusted entity type:**
   - AWS service → for EC2, Lambda, etc.
   - AWS account → for cross-account
   - Web identity → for OIDC (GitHub Actions, Kubernetes)
3. **Use case:** Select the service (e.g., EC2)
   - This pre-fills the trust policy for you
4. **Permissions:** Search and attach policies
5. **Name the role** (e.g., `vault-api-ec2-role`)
6. Create

---

## Creating a Role (CLI)

```bash
# Step 1: Write the trust policy to a file
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Step 2: Create the role
aws iam create-role \
  --role-name vault-api-ec2-role \
  --assume-role-policy-document file://trust-policy.json

# Step 3: Attach permission policies
aws iam attach-role-policy \
  --role-name vault-api-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Or attach a custom inline policy
aws iam put-role-policy \
  --role-name vault-api-ec2-role \
  --policy-name S3SpecificBucket \
  --policy-document file://s3-policy.json

# View the role
aws iam get-role --role-name vault-api-ec2-role

# View attached policies
aws iam list-attached-role-policies --role-name vault-api-ec2-role
```

---

## Users vs Roles — When to Use Each

| Scenario | Use |
|----------|-----|
| A human needs to log into AWS Console | IAM User |
| A script runs on your laptop | IAM User with access keys |
| An app runs on EC2 | IAM Role (attached to EC2) |
| A Lambda function needs AWS access | IAM Role (attached to Lambda) |
| A developer needs temporary elevated access | IAM Role (assumed via STS) |
| CI/CD pipeline (GitHub Actions) needs AWS access | IAM Role (with OIDC trust) |
| Another AWS account needs access to your resources | IAM Role (cross-account trust) |

**Rule of thumb:** If it's a machine or service → always a Role. If it's a human → User.

---

## Common Mistakes with Roles

### Mistake 1: Forgetting the trust policy

```
Error: "An error occurred (AccessDenied) when calling the AssumeRole operation:
User: arn:aws:iam::123456789012:user/shashank is not authorized to perform:
sts:AssumeRole on resource: arn:aws:iam::123456789012:role/my-role"

Fix: Add the user to the role's trust policy
```

### Mistake 2: Wrong service in trust policy

```
Scenario: Lambda function can't access S3
Root cause: Trust policy says "ec2.amazonaws.com" instead of "lambda.amazonaws.com"

Check: IAM → Roles → your-role → Trust relationships tab
```

### Mistake 3: Attaching a role to EC2 and not seeing permissions take effect

```
Scenario: EC2 has S3 role attached but aws s3 ls returns Access Denied

Causes:
1. Role has wrong permissions (check permission policies)
2. Instance profile wasn't attached correctly
3. Cached old credentials — wait 1-2 minutes or run:
   aws sts get-caller-identity   (should show role ARN, not user)
```

→ Continue to: `04-iam-for-services.md`
