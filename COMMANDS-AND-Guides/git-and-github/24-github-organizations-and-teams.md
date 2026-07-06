# Git & GitHub — 24: Organizations, Teams, and Access Control

> **Last updated:** June 25, 2026
> **Covers:** GitHub Orgs, Teams, repo permissions, branch protection, CODEOWNERS, audit log

**20-minute read. How to structure a GitHub account for a company or multi-developer team.**

---

## Personal Account vs Organization

```
Personal Account (github.com/shashank)
  ├── Your personal repos
  ├── Repos you're a collaborator on
  └── Solo projects

Organization (github.com/sanketika)
  ├── Multiple repos under one name
  ├── Teams with different permissions
  ├── Centralized billing
  ├── Org-wide policies
  └── Audit log of all member actions
```

**When to use an Organization:**
- Multiple repos for the same project/company
- Multiple developers with different access levels
- Need to share billing across a team
- Need audit logging for compliance

---

## Creating and Structuring an Org

```
github.com → + → New Organization
Name: sanketika
Email: admin@sanketika.in
Plan: Free / Team / Enterprise
```

Typical structure for a startup:

```
github.com/sanketika/
  ├── vault-api          (Node.js backend)
  ├── vault-frontend     (React app)
  ├── vault-infra        (Terraform + Helm)
  ├── vault-mobile       (React Native)
  └── .github            (org-level workflows, templates)
```

The `.github` repo is special — ISSUE_TEMPLATE, workflow templates, and profile README go here and apply org-wide.

---

## Teams — Groups with Permissions

Teams are groups of org members. You assign repo access to teams, not individuals.

```
Organization: sanketika
  ├── Team: @sanketika/backend-team
  │     Members: shashank, developer2, developer3
  │     Repos: vault-api (write), vault-infra (read)
  │
  ├── Team: @sanketika/frontend-team
  │     Members: developer4, developer5
  │     Repos: vault-frontend (write), vault-api (read)
  │
  ├── Team: @sanketika/devops-team
  │     Members: shashank, ops-engineer
  │     Repos: vault-infra (write), all repos (read)
  │
  └── Team: @sanketika/tech-leads
        Members: shashank
        Repos: all repos (admin)
```

### Nested Teams

```
@sanketika/engineering          (parent — all engineers)
  ├── @sanketika/backend        (child)
  ├── @sanketika/frontend       (child)
  └── @sanketika/mobile         (child)
```

### Permission Levels

| Level | What They Can Do |
|-------|-----------------|
| Read | View and clone repos |
| Triage | Manage issues/PRs (no code changes) |
| Write | Push branches, open PRs |
| Maintain | Manage repo settings (no destructive) |
| Admin | Full control including delete |

**Best practice:**
- Most developers: **Write** on their team's repos
- Tech leads: **Maintain** on their repos
- DevOps on all: **Write** (to push Helm/Terraform changes)
- Org owners: **Admin** on everything

---

## Repo Permissions: Individuals vs Teams

```
❌ Don't: Add individuals directly to repos
   vault-api → Collaborators → Add: developer2 (write)
   vault-api → Collaborators → Add: developer3 (write)
   (Hard to manage at scale, no consistency)

✓ Do: Add teams to repos
   vault-api → Manage access → Add team: backend-team (write)
   (When a new developer joins backend team → automatically gets write access to vault-api)
```

---

## Outside Collaborators

For contractors, agencies, open-source contributors who need access but aren't org members:

```
Repository → Settings → Collaborators → Add people
```

Outside collaborators are per-repo, not org-wide. They don't count toward your org seats (on most plans).

---

## Branch Protection at Org Level (Rulesets)

Organization rulesets apply to ALL repos in the org — you don't have to configure branch protection individually for each repo.

```
Organization Settings → Rules → Rulesets → New ruleset

Name: "Protect main branches"
Enforcement: Active

Target branches:
  Include: main, master, develop

Rules:
  ✓ Require pull request
    Required approvals: 1
  ✓ Require status checks
    Required checks: test, lint
  ✓ Block force pushes
  ✓ Require linear history
```

This applies to every repo in the org automatically. New repos inherit the protection.

---

## CODEOWNERS — Fine-Grained Review Requirements

CODEOWNERS ensures the right people review the right code.

```
# .github/CODEOWNERS

# Default: tech leads review everything not covered below
*                                 @sanketika/tech-leads

# API code: backend team
/src/api/                         @sanketika/backend-team
/src/services/                    @sanketika/backend-team

# Database: DBA must review all migrations
/migrations/                      @sanketika/backend-team @db-admin

# Frontend: frontend team
/src/components/                  @sanketika/frontend-team
/src/pages/                       @sanketika/frontend-team

# Infrastructure changes: DevOps must review
/helm/                            @sanketika/devops-team
/terraform/                       @sanketika/devops-team
/.github/workflows/               @sanketika/devops-team

# Security-sensitive: specific person required
/src/middleware/auth.js           @security-lead
/src/utils/crypto.js              @security-lead
```

**How it works in practice:**

```
Developer A opens PR:
  Changed files:
    src/api/vaults.js          → requests @sanketika/backend-team
    src/components/Button.jsx  → requests @sanketika/frontend-team

Review required from: backend-team AND frontend-team
(Because the PR crosses ownership boundaries)
```

---

## Environments — Deployment Approval Gates

Environments are named deployment targets with protection rules.

```
Settings → Environments → New environment: production

Required reviewers: @sanketika/tech-leads
Wait timer: 0 minutes
Deployment branches: main only
Secrets: PRODUCTION_KUBECONFIG, PROD_DB_URL
```

In your GitHub Actions workflow:

```yaml
jobs:
  deploy-production:
    environment: production    # ← this triggers the approval gate
    runs-on: ubuntu-latest
    steps:
    - run: helm upgrade vault-app ...
```

When this job runs:
1. GitHub pauses it
2. Sends a notification to `@sanketika/tech-leads`
3. They see a review button in GitHub
4. They click "Approve" → workflow resumes
5. Or they click "Reject" → workflow fails

**Secrets per environment:** The `PRODUCTION_KUBECONFIG` secret is only accessible to jobs running in the `production` environment. A job in `staging` environment can't access production secrets even if it tries. This is isolation by design.

---

## Audit Log — Who Did What and When

Every action in the org is logged.

```
Organization Settings → Audit log

Filter examples:
  action:repo.create              → who created repos
  action:member.add               → who added members
  action:protected_branch.create  → who added branch protection
  action:secrets.access           → who accessed secrets
  actor:shashank                  → everything shashank did
```

What's logged:
- Repository creation, deletion, visibility changes
- Branch protection added/removed
- Member added/removed/changed role
- Team created/deleted
- Secret accessed/created/deleted
- OAuth app authorized
- Workflow runs (with audit level: full)

**Export for compliance:**
```bash
gh api /orgs/sanketika/audit-log \
  --field phrase="action:repo.delete" \
  --field per_page=100 \
  --paginate \
  | jq '.[]' > audit-export.jsonl
```

---

## Single Sign-On (SSO) — Enterprise Feature

For companies with many employees, SSO forces all GitHub access to go through your identity provider (Okta, Azure AD, Google Workspace):

```
When employee onboards:
  IT provisions Okta account
  Okta syncs to GitHub Org
  → Employee automatically added to the right teams
  
When employee leaves:
  IT deactivates Okta account
  → All GitHub access revoked automatically
  (No manual GitHub access management)
```

Available on: GitHub Enterprise Cloud.

---

## The Real-World Setup Checklist

When setting up a GitHub Org for a team:

```
Organization:
  □ Created with company name
  □ Profile README in .github repo
  □ Default branch protection ruleset active
  □ Audit log retention configured
  □ 2FA required for all members

Teams:
  □ Teams created per function (backend, frontend, devops, etc.)
  □ Repos assigned to teams (not individuals)
  □ Team maintainers designated

Repositories:
  □ CODEOWNERS file in each major repo
  □ Issue templates created
  □ PR template created (.github/PULL_REQUEST_TEMPLATE.md)
  □ Branch protection on main/master

Environments (for deployed services):
  □ staging environment (auto-deploy, no approval)
  □ production environment (required approval from tech lead)
  □ Production secrets stored in production environment only

Security:
  □ Dependabot enabled on all repos
  □ Secret scanning enabled
  □ Code scanning workflow added
```

---

## Common Misunderstanding: "I should add everyone as Admin"

**The misunderstanding:** "To avoid permission issues, I'll just give everyone Admin access to the repos."

**The reality:** Least-privilege access prevents accidents. With Admin:
- Anyone can delete a repo
- Anyone can delete branch protection rules
- Anyone can add outside collaborators
- Anyone can merge without review

A developer doesn't need Admin to write code. They need Write access.

The typical rule: **Write access for developers, Admin only for designated infrastructure owners.**

If someone "can't do what they need" with Write access, solve that specific problem — don't escalate to Admin as a shortcut.

→ Return to: [README.md](README.md) to see the full guide
