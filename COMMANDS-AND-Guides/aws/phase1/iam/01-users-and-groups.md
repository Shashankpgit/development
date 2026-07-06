# IAM — 01: Users and Groups

> **Last updated:** July 5, 2026

---

## IAM Users

An **IAM User** is an identity you create in your AWS account for a person or an application.

Each user has:
- A unique name within the account
- Credentials to authenticate (password and/or access keys)
- Permissions attached via policies

### Two Types of Access

When you create a user, you choose what type of access they need:

```
Console Access (for humans)
  → Username + Password
  → Sign in at: https://123456789012.signin.aws.amazon.com/console
  → The number is your AWS account ID

Programmatic Access (for CLI/SDK/code)
  → Access Key ID:     AKIAIOSFODNN7EXAMPLE
  → Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
  → Used with: aws configure, boto3, terraform, etc.
```

A user can have both types.

**Important:** Access Key + Secret Key are like username+password for the CLI. If they leak, anyone can call AWS APIs as that user. Treat them like passwords.

---

## Creating a User (Console)

1. Go to **IAM → Users → Create user**
2. Enter username (e.g., `shashank`)
3. Choose:
   - ✅ Provide user access to the AWS Management Console
   - Set password (auto-generated or custom)
4. Next → Set permissions (attach to group, or skip for now)
5. Create user → **Download the CSV** (the only time you see the password)

---

## Creating a User (CLI)

```bash
# Create the user
aws iam create-user --user-name shashank

# Create a console password
aws iam create-login-profile \
  --user-name shashank \
  --password "TempPass@2026!" \
  --password-reset-required

# Create programmatic access keys
aws iam create-access-key --user-name shashank
# Output:
# {
#   "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
#   "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG...",
#   "Status": "Active"
# }
# ⚠️ Copy the SecretAccessKey NOW — it won't be shown again

# List users
aws iam list-users

# Delete a user
aws iam delete-user --user-name shashank
```

---

## Multi-Factor Authentication (MFA)

MFA adds a second factor — after entering the password, the user must also enter a 6-digit code from their phone.

**Why enable it:** Even if a password leaks, the attacker can't login without the physical device.

**Types:**
- Virtual MFA: Google Authenticator, Authy (most common)
- Hardware MFA: Physical YubiKey or token (for high-security accounts)

**Enable MFA for a user (Console):**
1. IAM → Users → click the user
2. Security credentials tab → MFA Device → Assign MFA device
3. Choose Virtual MFA → Scan QR code with Authenticator app
4. Enter two consecutive codes to verify

**Enforce MFA (policy):**

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Deny",
    "Action": "*",
    "Resource": "*",
    "Condition": {
      "BoolIfExists": {
        "aws:MultiFactorAuthPresent": "false"
      }
    }
  }]
}
```

This policy denies everything unless MFA was used to login.

---

## IAM Groups

A **Group** is just a collection of users. You attach policies to the group, and all users in the group inherit those permissions.

**Why use groups instead of attaching policies directly to users:**

Without groups (painful):
```
User: shashank   → Policy: S3ReadAccess, EC2FullAccess, CloudWatchRead
User: ravi       → Policy: S3ReadAccess, EC2FullAccess, CloudWatchRead
User: priya      → Policy: S3ReadAccess, EC2FullAccess, CloudWatchRead
User: new_hire   → (you have to remember to attach 3 policies manually)
```

With groups (clean):
```
Group: DevTeam   → Policy: S3ReadAccess, EC2FullAccess, CloudWatchRead
  ├── shashank
  ├── ravi
  ├── priya
  └── new_hire   (just add to group — they get everything automatically)
```

**Rules about groups:**
- A user can be in multiple groups
- Groups can't be nested (no group inside a group)
- Groups are NOT identities — you can't log in as a group, and you can't reference a group in a policy's Principal

### Creating a Group (CLI)

```bash
# Create the group
aws iam create-group --group-name DevTeam

# Add a user to the group
aws iam add-user-to-group --user-name shashank --group-name DevTeam

# Attach a managed policy to the group
aws iam attach-group-policy \
  --group-name DevTeam \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# List users in a group
aws iam get-group --group-name DevTeam

# Remove user from group
aws iam remove-user-from-group --user-name shashank --group-name DevTeam
```

---

## Common Group Structure (Real World)

```
AWS Account
  │
  ├── Group: Admins
  │     └── Policy: AdministratorAccess
  │     └── Users: [you — the account owner]
  │
  ├── Group: Developers
  │     └── Policy: PowerUserAccess (everything except IAM)
  │     └── Users: [dev team]
  │
  ├── Group: ReadOnly
  │     └── Policy: ReadOnlyAccess
  │     └── Users: [interns, auditors, external reviewers]
  │
  └── Group: Billing
        └── Policy: Billing (view/manage billing)
        └── Users: [finance team]
```

---

## Password Policy

You can set rules for all IAM user passwords in your account:

**Console:** IAM → Account settings → Password policy → Edit

```bash
# Set password policy via CLI
aws iam update-account-password-policy \
  --minimum-password-length 12 \
  --require-uppercase-characters \
  --require-lowercase-characters \
  --require-numbers \
  --require-symbols \
  --allow-users-to-change-password \
  --max-password-age 90 \
  --password-reuse-prevention 5
```

---

## What About Applications?

If your **application** (a script, a Lambda, a server) needs to call AWS APIs, you might think "create an IAM user with access keys for the app."

**Don't do this.** Use IAM Roles instead.

Reasons:
1. Access keys are long-lived — if they leak, they work forever until rotated
2. Keys stored in config files or code get accidentally committed to git
3. Roles use short-lived temporary credentials that auto-rotate every 15 minutes–1 hour

The next files cover Policies and Roles — which is the right approach for services.

→ Continue to: `02-policies-deep-dive.md`
