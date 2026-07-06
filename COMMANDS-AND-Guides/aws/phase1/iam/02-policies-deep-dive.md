# IAM — 02: Policies Deep Dive

> **Last updated:** July 5, 2026
> **This is where most confusion happens. Read slowly.**

---

## What Is a Policy?

A **policy** is a JSON document that defines what actions are allowed or denied on which resources.

Without a policy attached, **an IAM identity (user/role) can do NOTHING**. AWS defaults to denying everything. You have to explicitly grant permissions.

---

## The Anatomy of a Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3ReadOnMyBucket",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
```

Every policy is a JSON object with these fields:

### `Version`
Always `"2012-10-17"`. This is required. It specifies the policy language version. Don't change it.

### `Statement`
An array (list) of individual permission rules. A policy can have multiple statements.

### `Sid` (Statement ID)
Optional. A label for you to identify the statement. Doesn't affect behavior.

### `Effect`
Either `"Allow"` or `"Deny"`. That's it. Two options only.

### `Action`
Which AWS API calls this statement applies to.

```json
// Single action
"Action": "s3:GetObject"

// Multiple actions
"Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]

// All actions for a service
"Action": "s3:*"

// ALL actions on ALL services (admin)
"Action": "*"
```

Actions always follow the format: `service:ApiCallName`

```
s3:GetObject         → S3's GetObject API
ec2:RunInstances     → EC2's RunInstances API
iam:CreateUser       → IAM's CreateUser API
lambda:InvokeFunction → Lambda's InvokeFunction API
```

### `Resource`
Which specific resources this statement applies to.

```json
// Specific S3 bucket
"Resource": "arn:aws:s3:::my-bucket"

// All objects inside a bucket
"Resource": "arn:aws:s3:::my-bucket/*"

// Specific EC2 instance
"Resource": "arn:aws:ec2:ap-south-1:123456789:instance/i-abc123"

// ALL resources (use carefully)
"Resource": "*"

// Multiple resources
"Resource": [
  "arn:aws:s3:::bucket-a",
  "arn:aws:s3:::bucket-b"
]
```

---

## Multiple Statements in One Policy

A policy can have multiple statements. Each statement is evaluated independently.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3Read",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
    },
    {
      "Sid": "AllowEC2Describe",
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Sid": "DenyEC2Delete",
      "Effect": "Deny",
      "Action": "ec2:TerminateInstances",
      "Resource": "*"
    }
  ]
}
```

This policy:
- Allows reading from my-bucket
- Allows describing all EC2 resources
- Explicitly denies terminating EC2 instances

---

## The Condition Block

**Condition** makes the statement apply only when specific circumstances are true. This is where policies get powerful.

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-bucket/*",
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": ["203.0.113.0/24", "203.0.114.0/24"]
    }
  }
}
```

This allows GetObject only if the request comes from those IP ranges.

### Common Condition Keys

```json
// Only allow if MFA is present
"Condition": {
  "Bool": {
    "aws:MultiFactorAuthPresent": "true"
  }
}

// Only allow from specific IP
"Condition": {
  "IpAddress": {
    "aws:SourceIp": "10.0.0.0/8"
  }
}

// Only allow if request is over SSL/HTTPS
"Condition": {
  "Bool": {
    "aws:SecureTransport": "true"
  }
}

// Only allow between certain times
"Condition": {
  "DateGreaterThan": { "aws:CurrentTime": "2026-01-01T00:00:00Z" },
  "DateLessThan":    { "aws:CurrentTime": "2026-12-31T23:59:59Z" }
}

// Allow a user to only manage their own MFA device
"Condition": {
  "StringEquals": {
    "iam:ResourceTag/username": "${aws:username}"
  }
}
```

---

## Allow vs Deny — Who Wins?

This is critical to understand. The evaluation order:

```
1. Is there an explicit DENY?      → DENY immediately. No exceptions.
2. Is there an explicit ALLOW?     → ALLOW (unless overridden by deny above)
3. Nothing?                        → Implicit DENY (default)
```

**Explicit Deny always wins** — even if 10 policies allow something, one explicit Deny blocks it.

Example:
```
User "shashank" has:
  - Group policy: Allow s3:*
  - Individual policy: Deny s3:DeleteObject

Result:
  shashank CAN do all S3 actions (from group policy)
  shashank CANNOT delete objects (explicit deny overrides the group's Allow)
```

---

## Types of Policies

### 1. AWS Managed Policies (built-in, maintained by AWS)

AWS provides hundreds of pre-built policies. Common ones:

```
AdministratorAccess             → Full access to everything
PowerUserAccess                 → Full access except IAM management
ReadOnlyAccess                  → Read everything, change nothing
AmazonS3FullAccess              → Full S3 access
AmazonS3ReadOnlyAccess          → Read-only S3
AmazonEC2FullAccess             → Full EC2 access
AmazonRDSFullAccess             → Full RDS access
AWSLambdaFullAccess             → Full Lambda access
CloudWatchFullAccess            → Full CloudWatch access
AmazonDynamoDBFullAccess        → Full DynamoDB access
```

These are identified by their ARN starting with `arn:aws:iam::aws:policy/`
(Note: no account ID — they belong to AWS, not your account)

**When to use:** Fine for broad access. Don't use `AdministratorAccess` in production for app roles.

### 2. Customer Managed Policies (you create them)

You write your own JSON policy. It lives in your account.

ARN looks like: `arn:aws:iam::123456789012:policy/MyCustomPolicy`

**When to use:** When you need precise, least-privilege access for production workloads.

### 3. Inline Policies

A policy that is embedded directly inside a User, Group, or Role (not a separate object).

**When to use:** Almost never. Inline policies are harder to manage and can't be reused.

---

## Policy Wildcards

```
*     → Matches everything
?     → Matches any single character

Examples:
  "Action": "s3:*"              → All S3 actions
  "Action": "ec2:Describe*"     → All EC2 Describe actions (DescribeInstances, DescribeVpcs, etc.)
  "Resource": "arn:aws:s3:::logs-*"  → All buckets starting with "logs-"
```

---

## Real Policy Examples

### Let a developer read/write to one specific S3 bucket

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::vault-app-uploads/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::vault-app-uploads"
    }
  ]
}
```

Why two statements? `s3:ListBucket` applies to the bucket itself (`:::bucket-name`), while object actions apply to objects inside it (`:::bucket-name/*`). If you use `/*` for ListBucket, it won't work.

### Allow EC2 instance to write logs to CloudWatch

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ],
    "Resource": "arn:aws:logs:*:*:*"
  }]
}
```

### Allow only actions that don't cost money (read-only across everything)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ec2:Describe*",
      "s3:Get*",
      "s3:List*",
      "rds:Describe*",
      "iam:Get*",
      "iam:List*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "cloudwatch:Describe*"
    ],
    "Resource": "*"
  }]
}
```

---

## Common Mistakes

### Mistake 1: Using `Resource: "*"` when you should be specific

```json
// ❌ Too broad
{
  "Effect": "Allow",
  "Action": "s3:DeleteObject",
  "Resource": "*"   // can delete from ANY bucket
}

// ✅ Least privilege
{
  "Effect": "Allow",
  "Action": "s3:DeleteObject",
  "Resource": "arn:aws:s3:::my-app-bucket/*"   // only this bucket
}
```

### Mistake 2: Forgetting that ListBucket and object actions need different ARNs

```json
// ❌ Won't work for ListBucket
{
  "Effect": "Allow",
  "Action": ["s3:ListBucket", "s3:GetObject"],
  "Resource": "arn:aws:s3:::my-bucket/*"   // /* doesn't work for ListBucket
}

// ✅ Correct
{
  "Effect": "Allow",
  "Action": "s3:ListBucket",
  "Resource": "arn:aws:s3:::my-bucket"     // the bucket itself
},
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-bucket/*"   // objects inside
}
```

### Mistake 3: Expecting "no Allow" to work — there must be an explicit Allow

```
Developer has no policies attached → tries to list EC2 instances
Result: Denied (implicit deny)
Fix: Attach a policy with Allow ec2:DescribeInstances
```

---

## CLI: Working with Policies

```bash
# List all managed policies in your account
aws iam list-policies --scope Local    # your custom policies
aws iam list-policies --scope AWS      # AWS-managed policies

# Get the content of a policy
aws iam get-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Get the actual JSON of a policy version
aws iam get-policy-version \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --version-id v1

# Create a custom policy from a JSON file
aws iam create-policy \
  --policy-name MyS3Policy \
  --policy-document file://my-s3-policy.json

# Attach a policy to a user
aws iam attach-user-policy \
  --user-name shashank \
  --policy-arn arn:aws:iam::123456789012:policy/MyS3Policy

# List policies attached to a user
aws iam list-attached-user-policies --user-name shashank

# Detach a policy from a user
aws iam detach-user-policy \
  --user-name shashank \
  --policy-arn arn:aws:iam::123456789012:policy/MyS3Policy
```

→ Continue to: `03-roles-deep-dive.md`
