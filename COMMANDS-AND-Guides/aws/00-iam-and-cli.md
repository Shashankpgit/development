# AWS — Part 00: IAM and the AWS CLI

---

## IAM — Identity and Access Management

IAM is the security foundation of AWS. Everything in AWS has an identity, and every action is checked against IAM policies. Understanding IAM is not optional — it's the first thing you must learn.

### Core Concepts

**Account**: Your AWS billing entity. All resources live inside an account. The root account email/password = absolute superuser — never use it for daily work.

**User**: A person or application with permanent credentials (access key + secret, or password). Each user has policies attached that define what they can do.

**Group**: A collection of users. Attach policies to groups — all users in the group inherit those permissions.

**Role**: An identity that can be ASSUMED by a user, service, or AWS resource. Unlike a user, a role has no permanent credentials — it issues temporary credentials when assumed. Critical for:
- EC2 instances that need to access S3 (give the instance a role, never put credentials on the machine)
- Cross-account access
- Lambda functions, ECS tasks, EKS pods

**Policy**: A JSON document that says "allow or deny these actions on these resources."

**The IAM golden rule:** Give the minimum permissions needed to do the job. Never use AdministratorAccess in production.

---

## Policy Document Anatomy

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
      "Resource": "arn:aws:s3:::my-vault-app-bucket/*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "ap-south-1"
        }
      }
    },
    {
      "Effect": "Deny",
      "Action": "s3:DeleteObject",
      "Resource": "*"
    }
  ]
}
```

- `Effect`: `Allow` or `Deny` (Deny always wins if there's a conflict)
- `Action`: what operation (e.g., `s3:GetObject`, `ec2:StartInstances`, `*` = everything)
- `Resource`: what specific resource (ARN = Amazon Resource Name, the unique ID of every AWS resource)
- `Condition`: optional fine-grained conditions

---

## Installing and Configuring the AWS CLI

```bash
# Install AWS CLI v2 on Ubuntu/Debian
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
# aws-cli/2.x.x Python/3.x.x Linux/...
```

### Configure Credentials

```bash
aws configure
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: ap-south-1
# Default output format [None]: json    (or table, text)
```

This creates `~/.aws/credentials` and `~/.aws/config`.

### Named Profiles (Multiple Accounts)

```bash
# Configure a named profile
aws configure --profile production
aws configure --profile staging

# Use a specific profile
aws s3 ls --profile production
export AWS_PROFILE=production    # set for the whole session
```

```
~/.aws/credentials:
[default]
aws_access_key_id = ...
aws_secret_access_key = ...

[production]
aws_access_key_id = ...
aws_secret_access_key = ...

[staging]
aws_access_key_id = ...
aws_secret_access_key = ...
```

### Temporary Credentials via Role Assumption

```bash
# Assume a role (get temporary credentials)
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/ProductionDeploy \
  --role-session-name deploy-session

# The output gives you temporary AccessKeyId, SecretAccessKey, SessionToken
# Set them as environment variables:
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

---

## IAM CLI Commands

```bash
# Your current identity
aws sts get-caller-identity
# {
#   "UserId": "AIDAIOSFODNN7EXAMPLE",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/shashank"
# }

# List users
aws iam list-users

# List groups
aws iam list-groups

# List roles
aws iam list-roles

# Create a user
aws iam create-user --user-name deploy-bot

# Create access key for a user
aws iam create-access-key --user-name deploy-bot

# Create a policy
aws iam create-policy \
  --policy-name S3ReadOnly \
  --policy-document file://s3-readonly-policy.json

# Attach policy to user
aws iam attach-user-policy \
  --user-name deploy-bot \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnly

# Attach managed policy to user
aws iam attach-user-policy \
  --user-name shashank \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# Create a role
aws iam create-role \
  --role-name EC2S3Access \
  --assume-role-policy-document file://trust-policy.json

# Trust policy (who can assume this role — in this case, EC2):
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}

# Attach policy to role
aws iam attach-role-policy \
  --role-name EC2S3Access \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# List what policies are attached to a user
aws iam list-attached-user-policies --user-name shashank

# Simulate a policy (test if an action would be allowed)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/shashank \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/file.txt
```

---

## Common Misunderstanding: "IAM roles are only for EC2"

**The misunderstanding:** "IAM roles are something you attach to EC2 instances so they can access S3."

**The reality:** Roles are the universal identity mechanism in AWS. Everything uses roles:

- **EC2 instance**: assume a role to call S3/DynamoDB/etc. without putting credentials on disk
- **Lambda function**: has a role that allows it to write to CloudWatch, call other services
- **ECS task**: each task can have its own role (IRSA for EKS is similar)
- **Cross-account access**: "allow account B to assume a role in account A"
- **GitHub Actions CI/CD**: assume a role via OIDC (no long-lived access keys needed!)
- **Kubernetes pods (IRSA)**: pods assume an IAM role via service account annotation

The modern best practice: **no long-lived access keys anywhere**. Everything uses roles and temporary credentials. If you're using `aws configure` with an access key for a production workload running on AWS, you're doing it wrong — give the EC2/Lambda/pod a role instead.

→ Continue to: `01-ec2-and-vpc.md`
