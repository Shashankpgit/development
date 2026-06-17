# AWS — Zero to Hero Command Guide

## Reading Order

| # | File | What You'll Learn |
|---|------|-------------------|
| 00 | `00-iam-and-cli.md` | IAM users/groups/roles/policies, AWS CLI setup, profiles, credential best practices |
| 01 | `01-ec2-s3-vpc.md` | EC2 launch/manage, S3 buckets/objects/policies, VPC subnets/IGW/NAT Gateway |
| 02 | `02-rds-eks-cloudwatch.md` | RDS managed databases, EKS Kubernetes, IRSA, CloudWatch metrics/logs/alarms |

## Quick Command Reference

```bash
# Identity
aws sts get-caller-identity

# EC2
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
aws ec2 stop-instances --instance-ids i-xxxxx
aws ec2 start-instances --instance-ids i-xxxxx

# S3
aws s3 ls s3://bucket-name
aws s3 cp file.txt s3://bucket-name/
aws s3 sync ./dir/ s3://bucket-name/dir/

# EKS
aws eks update-kubeconfig --region ap-south-1 --name cluster-name
eksctl create cluster --name my-cluster --region ap-south-1

# RDS
aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier,Endpoint.Address]"

# CloudWatch
aws cloudwatch describe-alarms --state-value ALARM
```

## Key Best Practices

1. **Never use root account** for daily operations — create IAM users
2. **No long-lived access keys on EC2** — use IAM roles (instance profiles) instead
3. **Databases in private subnets** — never expose RDS directly to the internet
4. **Enable MFA** on all IAM users with console access
5. **Enable CloudTrail** — audit log of all API calls in your account
6. **Tag everything** — `Name`, `Environment`, `Owner`, `Project` tags for cost tracking
