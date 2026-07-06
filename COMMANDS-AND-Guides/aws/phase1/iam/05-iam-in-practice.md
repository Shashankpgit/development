# IAM — 05: IAM in Practice

> **Last updated:** July 5, 2026
> **Debugging Access Denied, IAM Policy Simulator, and real-world patterns.**

---

## Debugging "Access Denied" — Step by Step

When you see this error:
```
An error occurred (AccessDenied) when calling the GetObject operation:
User: arn:aws:iam::123456789012:user/shashank is not authorized to perform:
s3:GetObject on resource: "arn:aws:s3:::prod-bucket/config.json"
```

**Step 1: Identify what identity is making the call**

The error message tells you: `User: arn:aws:iam::123456789012:user/shashank`

Or run:
```bash
aws sts get-caller-identity
# {
#   "UserId": "AIDAIOSFODNN7EXAMPLE",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/shashank"
# }
```

**Step 2: Check what policies are attached to that identity**

```bash
# For a user:
aws iam list-attached-user-policies --user-name shashank
aws iam list-user-policies --user-name shashank   # inline policies

# For a role:
aws iam list-attached-role-policies --role-name vault-api-role
aws iam list-role-policies --role-name vault-api-role

# For groups the user belongs to:
aws iam list-groups-for-user --user-name shashank
# Then check each group:
aws iam list-attached-group-policies --group-name DevTeam
```

**Step 3: Read the policy content**

```bash
# Get an attached managed policy
aws iam get-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Get the actual JSON (use the DefaultVersionId from above)
aws iam get-policy-version \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --version-id v1

# Get an inline policy
aws iam get-user-policy --user-name shashank --policy-name my-inline-policy
aws iam get-role-policy --role-name vault-api-role --policy-name my-inline-policy
```

**Step 4: Check for explicit Deny**

Even if you have an Allow, an explicit Deny overrides it. Check if there's an SCP (Service Control Policy) at the organization level:

```bash
# List SCPs attached to the account
aws organizations list-policies-for-target \
  --target-id 123456789012 \
  --filter SERVICE_CONTROL_POLICY
```

**Step 5: Check the resource-based policy**

For S3, there may also be a bucket policy that denies access:

```bash
aws s3api get-bucket-policy --bucket prod-bucket
```

---

## IAM Policy Simulator

The **IAM Policy Simulator** is a tool to test whether a user/role has permission to do something — without actually doing it.

**Console:** https://policysim.aws.amazon.com

Or via CLI:

```bash
# Simulate whether user "shashank" can do s3:GetObject
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/shashank \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::prod-bucket/config.json

# Output:
# {
#   "EvaluationResults": [{
#     "EvalActionName": "s3:GetObject",
#     "EvalResourceName": "arn:aws:s3:::prod-bucket/config.json",
#     "EvalDecision": "allowed",     ← or "explicitDeny" or "implicitDeny"
#     "MatchedStatements": [...]
#   }]
# }
```

---

## IAM Best Practices (The Rules)

### 1. Root Account
```
✅ Enable MFA on root immediately
✅ Create an IAM admin user for daily use
❌ Never use root for day-to-day work
❌ Never create access keys for root
```

### 2. Users and Groups
```
✅ Create individual users for each person (never share credentials)
✅ Assign permissions via groups, not individual users
✅ Enable MFA for all users with console access
✅ Rotate access keys regularly (aws iam create-access-key creates a new one — delete old)
❌ Never share IAM user credentials
❌ Never embed access keys in application code
```

### 3. Least Privilege
```
✅ Grant only the minimum permissions needed
✅ Start with read-only; add write when needed
✅ Scope resources to specific ARNs, not "*" when possible
✅ Use IAM Access Analyzer to find overly permissive policies
```

### 4. Roles
```
✅ Use roles for all AWS services (EC2, Lambda, ECS, etc.)
✅ Use roles for cross-account access
✅ Use OIDC roles for CI/CD (GitHub Actions)
❌ Never give a service an IAM user + access keys
```

---

## Useful CLI Commands Reference

```bash
# ── CURRENT IDENTITY ──────────────────────────────────────────
aws sts get-caller-identity

# ── USERS ─────────────────────────────────────────────────────
aws iam list-users
aws iam get-user --user-name shashank
aws iam create-user --user-name newuser
aws iam delete-user --user-name newuser

# ── ACCESS KEYS ───────────────────────────────────────────────
aws iam list-access-keys --user-name shashank
aws iam create-access-key --user-name shashank
aws iam delete-access-key --user-name shashank --access-key-id AKIAIOSFODNN7EXAMPLE
aws iam update-access-key --user-name shashank --access-key-id AKIAIOSFODNN7EXAMPLE --status Inactive

# ── GROUPS ────────────────────────────────────────────────────
aws iam list-groups
aws iam list-groups-for-user --user-name shashank
aws iam add-user-to-group --user-name shashank --group-name DevTeam
aws iam remove-user-from-group --user-name shashank --group-name DevTeam

# ── ROLES ─────────────────────────────────────────────────────
aws iam list-roles
aws iam get-role --role-name vault-api-role
aws iam create-role --role-name my-role --assume-role-policy-document file://trust.json
aws iam delete-role --role-name my-role

# ── POLICIES ──────────────────────────────────────────────────
aws iam list-attached-user-policies --user-name shashank
aws iam list-attached-role-policies --role-name vault-api-role
aws iam attach-role-policy --role-name my-role --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam detach-role-policy --role-name my-role --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam put-role-policy --role-name my-role --policy-name inline-policy --policy-document file://policy.json
aws iam delete-role-policy --role-name my-role --policy-name inline-policy

# ── ASSUME ROLE ───────────────────────────────────────────────
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/my-role \
  --role-session-name test-session
```

---

## IAM Access Analyzer

AWS IAM Access Analyzer automatically scans your account and tells you if any resources are accessible from outside your account (public S3 buckets, roles that external accounts can assume, etc.).

```bash
# Create an analyzer (checks your account)
aws accessanalyzer create-analyzer \
  --analyzer-name my-analyzer \
  --type ACCOUNT

# List findings (things that are publicly or externally accessible)
aws accessanalyzer list-findings --analyzer-name my-analyzer

# Validate a policy for best practices
aws accessanalyzer validate-policy \
  --policy-document file://my-policy.json \
  --policy-type IDENTITY_POLICY
```

---

## Common Exam Patterns

| Question Pattern | Answer |
|-----------------|--------|
| EC2 app needs S3 access | IAM Role with EC2 trust + S3 policy, attach to EC2 |
| Lambda needs DynamoDB | IAM Role with Lambda trust + DynamoDB policy |
| GitHub Actions needs to deploy | IAM Role with OIDC trust (no stored credentials) |
| Developer needs temporary admin access | Role with Admin permissions, user assumes via STS |
| Block all S3 actions for everyone except one role | Bucket policy with Deny + condition ArnNotLike |
| Enforce MFA for all console access | IAM policy with Deny when MFA not present |
| Service in Account A needs resources in Account B | Cross-account Role in Account B, trusted by Account A |

→ You've completed the IAM section. Continue to: `../vpc/00-mental-model.md`
