# IAM — 04: IAM for AWS Services

> **Last updated:** July 5, 2026
> **How EC2, Lambda, ECS, and other services use IAM roles in practice.**

---

## The Pattern: Every Service Needs a Role

When an AWS service needs to call other AWS services on your behalf, it needs a role.

The pattern is always:
1. Create a role with the right **trust policy** (which service can assume it)
2. Attach **permission policies** (what it can do)
3. Attach the role to the service

---

## EC2 — Instance Profile

### Full Walkthrough: EC2 App That Reads Config from S3 and Writes Logs to CloudWatch

**Step 1: Create the permission policy**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadAppConfig",
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::vault-app-config/*"
    },
    {
      "Sid": "WriteCloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

**Step 2: Create the role**

```bash
# Trust policy (EC2 can assume this role)
cat > ec2-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name vault-api-role \
  --assume-role-policy-document file://ec2-trust.json

aws iam put-role-policy \
  --role-name vault-api-role \
  --policy-name vault-api-permissions \
  --policy-document file://vault-api-policy.json
```

**Step 3: Attach to EC2 (at launch time)**

In the EC2 Launch wizard:
- Under "Advanced details" → IAM instance profile → Select `vault-api-role`

Or attach to a running instance:
```bash
aws ec2 associate-iam-instance-profile \
  --instance-id i-1234567890abcdef0 \
  --iam-instance-profile Name=vault-api-role
```

**Step 4: In your app on EC2 (no credentials needed)**

```javascript
// Node.js
const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');
const s3 = new S3Client({ region: 'ap-south-1' });
// AWS SDK automatically uses instance role credentials

const response = await s3.send(new GetObjectCommand({
  Bucket: 'vault-app-config',
  Key: 'settings.json'
}));
```

```python
# Python boto3
import boto3
s3 = boto3.client('s3')  # No credentials — reads from instance metadata
config = s3.get_object(Bucket='vault-app-config', Key='settings.json')
```

**Verify the role is working from inside EC2:**
```bash
# SSH into EC2 and run:
aws sts get-caller-identity

# Output shows the role:
# {
#   "UserId": "AROAIOSFODNN7EXAMPLE:i-1234567890abcdef0",
#   "Account": "123456789012",
#   "Arn": "arn:aws:sts::123456789012:assumed-role/vault-api-role/i-1234567890abcdef0"
# }

aws s3 ls s3://vault-app-config/   # should work
aws s3 ls s3://some-other-bucket/  # should fail (not in policy)
```

---

## Lambda — Execution Role

Every Lambda function has an **Execution Role** — the role Lambda assumes to run your function.

**Minimum role every Lambda needs:**

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ],
    "Resource": "arn:aws:logs:*:*:*"
  }]
}
```

Without this, your Lambda function can't even write logs to CloudWatch.

**Lambda execution role trust policy (automatically set when you use the console):**

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

**Full example: Lambda that processes S3 events and writes to DynamoDB**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::vault-uploads/*"
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:PutItem", "dynamodb:UpdateItem"],
      "Resource": "arn:aws:dynamodb:ap-south-1:123456789012:table/FileMetadata"
    }
  ]
}
```

**Create role and attach to Lambda via CLI:**

```bash
# Create execution role
aws iam create-role \
  --role-name vault-lambda-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach basic Lambda policy (logs)
aws iam attach-role-policy \
  --role-name vault-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Attach additional custom policy
aws iam put-role-policy \
  --role-name vault-lambda-role \
  --policy-name lambda-s3-dynamodb \
  --policy-document file://lambda-permissions.json

# Create Lambda with this role
aws lambda create-function \
  --function-name process-uploads \
  --runtime nodejs20.x \
  --role arn:aws:iam::123456789012:role/vault-lambda-role \
  --handler index.handler \
  --zip-file fileb://function.zip
```

---

## ECS/EKS — Task Role vs Execution Role

ECS has TWO separate roles — this confuses everyone.

```
Task Execution Role    → Used by the ECS AGENT (the infrastructure)
                         Pulls the container image from ECR
                         Reads secrets from Secrets Manager
                         Writes logs to CloudWatch
                         → You never write code that uses this role

Task Role              → Used by YOUR APPLICATION CODE running in the container
                         Reads S3, writes DynamoDB, calls other AWS services
                         → This is what your app code uses
```

Think of it this way:
- **Execution Role** = the role for the janitor (ECS agent) who sets up the room
- **Task Role** = the role for the employee (your app) who works in the room

**Task Execution Role (needed for every ECS task):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

AWS has a managed policy for this: `AmazonECSTaskExecutionRolePolicy`

**Task Role (what your app uses):**

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:PutObject"],
    "Resource": "arn:aws:s3:::vault-data/*"
  }]
}
```

**In a Task Definition:**

```json
{
  "family": "vault-api",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/vault-api-task-role",
  "containerDefinitions": [...]
}
```

---

## GitHub Actions (OIDC) — No Stored Credentials

GitHub Actions can assume an AWS role without storing any AWS credentials in GitHub Secrets. This uses **OIDC (OpenID Connect)**.

**How it works:**
1. GitHub generates a short-lived OIDC token for the workflow
2. The token says "this is a workflow from repo org/vault-app, branch main"
3. AWS verifies the token with GitHub's public keys
4. AWS issues temporary credentials

**Setup (one time):**

```bash
# 1. Create OIDC provider in AWS
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2. Create IAM role with GitHub trust policy
aws iam create-role \
  --role-name github-actions-deploy \
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
```

**GitHub Actions workflow:**

```yaml
name: Deploy
on:
  push:
    branches: [main]

permissions:
  id-token: write    # required for OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Assume AWS role via OIDC
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::123456789012:role/github-actions-deploy
        aws-region: ap-south-1

    - name: Deploy (CLI now works with role permissions)
      run: aws s3 sync ./dist s3://vault-frontend/
```

No secrets stored anywhere. The OIDC token proves the workflow's identity.

---

## Quick Reference: Which Role Trust Principal?

| Service | Trust Principal in Trust Policy |
|---------|--------------------------------|
| EC2 | `"Service": "ec2.amazonaws.com"` |
| Lambda | `"Service": "lambda.amazonaws.com"` |
| ECS Tasks | `"Service": "ecs-tasks.amazonaws.com"` |
| EKS (IRSA) | `"Federated": "arn:aws:iam::ACCT:oidc-provider/..."` |
| GitHub Actions | `"Federated": "arn:aws:iam::ACCT:oidc-provider/token.actions.githubusercontent.com"` |
| CloudFormation | `"Service": "cloudformation.amazonaws.com"` |
| CodePipeline | `"Service": "codepipeline.amazonaws.com"` |
| Another account | `"AWS": "arn:aws:iam::OTHER_ACCT:root"` |

→ Continue to: `05-iam-in-practice.md`
