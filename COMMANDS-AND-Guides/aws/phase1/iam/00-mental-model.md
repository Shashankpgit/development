# IAM — 00: Mental Model

> **Last updated:** July 5, 2026
> **Phase:** 1 — Foundation
> **Read this first before any other IAM file.**

---

## The Problem IAM Solves

Imagine you have a building (your AWS account). Inside the building are rooms full of valuable things — S3 buckets with data, EC2 servers, RDS databases.

Without IAM:
- Anyone who enters the building can go into any room
- You can't track who touched what
- You can't say "you can read files but not delete them"

IAM is the **security system for your entire AWS account**. It controls:
- **Who** can enter (authentication)
- **What** they can do once inside (authorization)
- **Which rooms** they can access (resource-level permissions)

---

## The 4 Things IAM Manages

```
┌─────────────────────────────────────────────────────────────┐
│                        IAM                                  │
│                                                             │
│   Users    → A person or app with a permanent identity     │
│   Groups   → A collection of users (easier management)     │
│   Roles    → A temporary identity (assumed, not permanent) │
│   Policies → A document that says what's allowed/denied    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Think of it like a company:
- **User** = An employee with their own badge
- **Group** = A department (Engineering, Finance) — everyone in the department gets the same door access
- **Role** = A contractor's temporary access badge — valid for today's job, expires when done
- **Policy** = The rulebook that says "badge level 3 can enter rooms A, B, C"

---

## What Is an ARN?

Every resource in AWS has a unique ID called an **ARN (Amazon Resource Name)**.

```
arn:aws:iam::123456789012:user/shashank
 │    │    │       │         │
 │    │    │       │         └── resource path
 │    │    │       └─────────── AWS account ID
 │    │    └─────────────────── service (iam, s3, ec2...)
 │    └──────────────────────── partition (always "aws")
 └───────────────────────────── prefix (always "arn")
```

More examples:
```
arn:aws:s3:::my-bucket                             ← S3 bucket (no region, no account)
arn:aws:s3:::my-bucket/*                           ← all objects in bucket
arn:aws:ec2:ap-south-1:123456789:instance/i-abc123 ← specific EC2 instance
arn:aws:iam::123456789:role/my-ec2-role            ← an IAM role
```

You use ARNs in policies to say exactly which resources are affected.

---

## How IAM Fits Into Everything

```
You (human) login to AWS Console
    ↓
IAM authenticates: "Is this the right password + MFA?"
    ↓
IAM checks: "What are this user's permissions?"
    ↓
User tries to create an EC2 instance
    ↓
IAM checks policies: "Is ec2:RunInstances allowed?"
    ↓
Allow → EC2 instance created
Deny  → "You are not authorized to perform this operation"
```

The same flow happens for:
- AWS CLI commands
- SDK calls from your code
- EC2 instance calling S3 (but using a Role instead of a User)
- Lambda function reading DynamoDB

**IAM is involved in EVERY single action in AWS. It's the foundation.**

---

## The Root Account — Never Use It

When you first create an AWS account, you have a **root account** — it's the email + password you signed up with.

The root account:
- Has unlimited power — cannot be restricted by any IAM policy
- Can close the account, change billing, remove all IAM users
- If compromised, it's game over

**Rules:**
1. Enable MFA on root immediately
2. Create an IAM admin user — use that for daily work
3. Lock the root credentials away — only use root for account-level tasks (billing, support plan changes)

---

## IAM Is Global

Unlike most AWS services (EC2, RDS, S3) which are regional, **IAM is global**.

An IAM user, role, or policy you create is available in **all AWS regions** automatically. You don't need to create separate IAM users per region.

---

## What's Next

Read these files in order:

| File | What It Covers |
|------|---------------|
| `01-users-and-groups.md` | Creating users, access types, MFA, groups |
| `02-policies-deep-dive.md` | How policy JSON works, effect/action/resource/condition |
| `03-roles-deep-dive.md` | Trust policies, permission policies, when to use roles — the confusing part |
| `04-iam-for-services.md` | How EC2, Lambda, and other services use IAM |
| `05-iam-in-practice.md` | CLI commands, debugging "Access Denied", policy simulator |

→ Continue to: `01-users-and-groups.md`
