1. Identity Fundamentals
        ↓
2. IAM Users
        ↓
3. IAM Groups
        ↓
4. IAM Roles
        ↓
5. IAM Policies
        ↓
6. Policy Evaluation Logic
        ↓
7. Policy JSON Language
        ↓
8. Authentication (Passwords, MFA, Access Keys)
        ↓
9. AWS CLI & SDK Credentials
        ↓
10. STS & Temporary Credentials
        ↓
11. IAM Identity Center (AWS SSO)
        ↓
12. Federation (SAML, OIDC)
        ↓
13. Resource Policies
        ↓
14. Advanced IAM Controls
        ↓
15. IAM Troubleshooting
        ↓
16. Production Architectures & Case Studies


# Important Production Rule

| Identity           | Recommended Credential    |
| ------------------ | ------------------------- |
| Human developer    | IAM Identity Center (SSO) |
| CLI (personal lab) | Access Keys               |
| EC2                | IAM Role                  |
| Lambda             | IAM Role                  |
| EKS Pod            | IRSA                      |
| GitHub Actions     | OIDC + IAM Role           |



1. Learn to check the activity histroy, like what are all the things i have done in the cluster like that.