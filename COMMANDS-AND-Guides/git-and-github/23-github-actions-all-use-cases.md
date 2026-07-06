# Git & GitHub — 23: GitHub Actions — All Use Cases

> **Last updated:** June 25, 2026
> **Covers:** Every major thing GitHub Actions can do — not just CI/CD. 20+ distinct use cases.

**20-minute read. Most developers use Actions for 2 things. It can do 20+.**

---

## GitHub Actions Is a General-Purpose Automation Platform

Most developers think:
> "GitHub Actions = CI/CD. It tests my code and deploys it."

That's 2 of the 20+ things it does. The real definition:

> **GitHub Actions is an event-driven automation platform. Any event in GitHub can trigger any script you write.**

Events: push, PR opened, issue created, comment posted, cron schedule, manual button, webhook, another workflow, release published, member added, deployment...

Anything that happens in GitHub can trigger automation. The script can do anything a Linux machine with internet access can do.

---

## Category 1: CI/CD (The Common One)

Already covered in the `github-actions/` guide. Quick summary:

```yaml
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - run: npm test
  
  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
    - run: helm upgrade ...
```

---

## Category 2: Automated Releases

Trigger: Push a version tag → release created automatically.

```yaml
on:
  push:
    tags: ['v*.*.*']

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0    # needed for changelog

    - name: Generate changelog
      id: changelog
      uses: orhun/git-cliff-action@v3    # generates changelog from commit messages

    - name: Create Release
      uses: softprops/action-gh-release@v2
      with:
        body: ${{ steps.changelog.outputs.content }}
        generate_release_notes: true
```

Developer does:
```bash
git tag v1.3.0
git push origin v1.3.0
# → GitHub Release created automatically with generated changelog
```

---

## Category 3: Issue and PR Automation (Bot Behavior)

### Auto-Label PRs Based on Files Changed

```yaml
# .github/labeler.yml
backend:
  - src/api/**
  - src/services/**
  - migrations/**

frontend:
  - src/components/**
  - src/pages/**

devops:
  - .github/workflows/**
  - helm/**
  - Dockerfile
```

```yaml
# .github/workflows/label.yml
on: [pull_request]
jobs:
  label:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/labeler@v5
      with:
        repo-token: ${{ secrets.GITHUB_TOKEN }}
```

Every PR touching `helm/` automatically gets the `devops` label. Every PR touching `src/api/` gets `backend`.

### Auto-Assign Reviewers

```yaml
on: [pull_request]
jobs:
  assign:
    runs-on: ubuntu-latest
    steps:
    - uses: hmarr/auto-assign-action@v4
      with:
        reviewers: shashank, developer2, developer3
        reviewers-per-pr: 2      # randomly pick 2 from the list
```

### Close Stale Issues

```yaml
on:
  schedule:
  - cron: '0 0 * * *'   # run daily at midnight

jobs:
  stale:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/stale@v9
      with:
        stale-issue-message: >
          This issue has been inactive for 30 days.
          It will be closed in 7 days unless there's activity.
        close-issue-message: >
          Closed due to inactivity. Reopen if still relevant.
        days-before-stale: 30
        days-before-close: 7
        stale-issue-label: 'stale'
        exempt-issue-labels: 'pinned,security,bug'
```

### Welcome New Contributors

```yaml
on:
  pull_request:
    types: [opened]

jobs:
  welcome:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/github-script@v7
      with:
        script: |
          const { data: pullRequests } = await github.rest.pulls.list({
            owner: context.repo.owner,
            repo: context.repo.repo,
            state: 'all',
            creator: context.payload.pull_request.user.login
          });
          
          if (pullRequests.length === 1) {
            // First-ever PR from this user
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `🎉 Thank you for your first contribution @${context.payload.pull_request.user.login}! 
              One of our team members will review this shortly.`
            });
          }
```

---

## Category 4: Scheduled Jobs (Cron)

### Weekly Dependency Audit

```yaml
on:
  schedule:
  - cron: '0 9 * * 1'    # every Monday 9am UTC

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - run: npm audit --audit-level=moderate
    - name: Create issue if audit fails
      if: failure()
      uses: actions/github-script@v7
      with:
        script: |
          await github.rest.issues.create({
            owner: context.repo.owner,
            repo: context.repo.repo,
            title: 'Weekly security audit failed',
            body: 'Run `npm audit` locally to see the full report.',
            labels: ['security', 'automated']
          });
```

### Nightly Database Backup

```yaml
on:
  schedule:
  - cron: '0 2 * * *'    # every day at 2am UTC

jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::123:role/backup-role
        aws-region: ap-south-1

    - name: Dump database and upload to S3
      run: |
        pg_dump ${{ secrets.DATABASE_URL }} | gzip > backup.sql.gz
        aws s3 cp backup.sql.gz s3://vault-backups/$(date +%Y-%m-%d)/
```

### Sync External Data

```yaml
on:
  schedule:
  - cron: '0 * * * *'    # every hour

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - run: |
        # Fetch latest data from an API and commit if changed
        curl https://api.example.com/data > data/latest.json
        git diff --quiet || (git add data/ && git commit -m "chore: sync external data" && git push)
```

---

## Category 5: Notifications and ChatOps

### Slack Notifications for Deployments

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    channel-id: 'C12345678'    # #deployments channel
    payload: |
      {
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*${{ github.repository }}* deployed to production\n
                       Version: `${{ github.ref_name }}`\n
                       By: ${{ github.actor }}\n
                       <${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View run>"
            }
          }
        ]
      }
  env:
    SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

### Notify on Failed Build

```yaml
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]

jobs:
  notify:
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
    runs-on: ubuntu-latest
    steps:
    - uses: slackapi/slack-github-action@v1
      with:
        channel-id: 'C12345678'
        slack-message: "❌ Build failed on `${{ github.event.workflow_run.head_branch }}` by ${{ github.event.workflow_run.actor.login }}"
      env:
        SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

---

## Category 6: Documentation Automation

### Auto-Generate API Docs from Code

```yaml
on:
  push:
    branches: [main]
    paths: ['src/api/**']

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - run: npm ci
    - run: npm run generate-docs    # generates OpenAPI spec from JSDoc
    - run: |
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add docs/api.json
        git diff --staged --quiet || git commit -m "docs: update API reference"
        git push
```

### Deploy Docs on Every Merge

```yaml
on:
  push:
    branches: [main]
    paths: ['docs/**', 'mkdocs.yml']

jobs:
  deploy-docs:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - run: pip install mkdocs-material
    - run: mkdocs gh-deploy --force
```

---

## Category 7: Infrastructure Automation

### Terraform Plan on PR, Apply on Merge

```yaml
# On every PR to main — show what Terraform would change
on:
  pull_request:
    paths: ['terraform/**']

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: hashicorp/setup-terraform@v3
    - run: terraform init
    - name: Terraform Plan
      id: plan
      run: terraform plan -out=plan.tfplan

    - name: Comment plan on PR
      uses: actions/github-script@v7
      with:
        script: |
          const output = `${{ steps.plan.outputs.stdout }}`;
          await github.rest.issues.createComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: context.issue.number,
            body: `## Terraform Plan\n\`\`\`\n${output}\n\`\`\``
          });
```

```yaml
# On merge to main — apply Terraform
on:
  push:
    branches: [main]
    paths: ['terraform/**']

jobs:
  apply:
    environment: production    # requires manual approval in GitHub
    steps:
    - run: terraform apply -auto-approve
```

---

## Category 8: Code Quality Enforcement

### Lint and Format Check

```yaml
on: [pull_request]
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - run: npm ci
    - run: npm run lint
    - run: npm run type-check
    - run: npm run format:check   # fail if unformatted files

    - name: Post lint errors as PR comments
      if: failure()
      uses: actions/github-script@v7
```

### Enforce Commit Message Format

```yaml
on: [pull_request]
jobs:
  commitlint:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
    - run: npx commitlint --from ${{ github.event.pull_request.base.sha }} --to ${{ github.event.pull_request.head.sha }}
```

Blocks PRs where commit messages don't follow `feat:`, `fix:`, `chore:` convention.

---

## Category 9: Cross-Repo Automation

### Trigger Workflow in Another Repo

```yaml
# In repo A — after successful deployment, trigger repo B's tests
- name: Trigger integration tests in vault-e2e repo
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.CROSS_REPO_TOKEN }}
    script: |
      await github.rest.repos.createDispatchEvent({
        owner: context.repo.owner,
        repo: 'vault-e2e-tests',
        event_type: 'api-deployed',
        client_payload: {
          api_version: '${{ github.ref_name }}',
          environment: 'staging'
        }
      });
```

```yaml
# In vault-e2e-tests repo — receives the trigger
on:
  repository_dispatch:
    types: [api-deployed]

jobs:
  e2e:
    steps:
    - run: npm run test:e2e -- --env ${{ github.event.client_payload.environment }}
```

---

## Category 10: Security Automation

### Container Vulnerability Scanning on Every Build

```yaml
on: [push]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Build image
      run: docker build -t vault-api:test .

    - name: Scan with Trivy
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: vault-api:test
        format: sarif
        output: trivy-results.sarif
        severity: CRITICAL,HIGH
        exit-code: 1    # fail the build if critical/high vulns found

    - uses: github/codeql-action/upload-sarif@v3
      if: always()
      with:
        sarif_file: trivy-results.sarif
```

### Rotate Secrets Automatically

```yaml
on:
  schedule:
  - cron: '0 0 1 * *'    # first of every month

jobs:
  rotate:
    steps:
    - name: Generate new API key via AWS Secrets Manager
      run: |
        aws secretsmanager rotate-secret \
          --secret-id prod/vault-api/jwt-secret

    - name: Update GitHub Secret
      uses: actions/github-script@v7
      with:
        script: |
          // Update the GitHub secret with the new value
          // (using Sodium encryption as required by GitHub API)
```

---

## All Use Cases — Quick Reference

| Category | What It Does |
|----------|-------------|
| CI | Run tests on every push/PR |
| CD | Deploy to staging/prod on merge |
| Releases | Create GitHub Release when tag is pushed |
| PR Automation | Auto-label, auto-assign, welcome messages |
| Issue Automation | Close stale, auto-label by type |
| Cron Jobs | Weekly audit, nightly backup, hourly sync |
| Notifications | Slack on deploy, Slack on failure, PagerDuty |
| Documentation | Generate and deploy docs on every merge |
| Code Quality | Lint, format, type-check as PR gates |
| Security | Container scan, SAST, secret rotation |
| Infrastructure | Terraform plan/apply, cost estimation |
| Cross-repo | Trigger workflows in other repos |
| Dependency updates | Supplement or trigger Dependabot |
| Changelog | Auto-generate from commits |
| Metrics | Push build/test metrics to Datadog/Prometheus |
| Environment management | Create/destroy ephemeral environments per PR |
| Database migrations | Run migrations as part of deploy pipeline |
| Performance testing | Run k6/artillery on staging after deploy |
| Package publishing | Publish to npm/PyPI/Maven on release |
| Mobile | Build iOS/Android, upload to TestFlight/Play Console |

---

## Common Misunderstanding: "Cron jobs need a server"

**The misunderstanding:** "I need an EC2 instance or a cron job on a VM to run scheduled tasks."

**The reality:** GitHub Actions cron is free for public repos and included in all plans. Your scheduled job:
- Runs on GitHub's servers (no infrastructure to manage)
- Gets a full Linux environment
- Has access to your secrets
- Can call any API, run any script

For lightweight scheduled tasks: GitHub Actions is free, zero-ops, and already where your code lives. Only move to a dedicated scheduler (Kubernetes CronJob, AWS EventBridge) when you need sub-minute scheduling, more than the free minutes, or very long-running jobs.

→ Continue to: `24-github-organizations-and-teams.md`
