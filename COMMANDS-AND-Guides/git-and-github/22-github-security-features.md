# Git & GitHub — 22: GitHub Security Features

> **Last updated:** June 25, 2026
> **Covers:** Dependabot, Secret Scanning, Code Scanning, Branch Protection, Security Advisories

**20-minute read. Security features that run automatically on your repo — most are free.**

---

## The Security Problem in Open Source

Your project depends on 500+ npm packages. You wrote maybe 5,000 lines of code. The rest (tens of thousands of lines) comes from dependencies you didn't write and can't fully audit.

When a vulnerability is found in a dependency:
1. A CVE (Common Vulnerability and Exposure) is published
2. GitHub cross-references all repos using that dependency
3. You get a Dependabot Alert (if enabled)
4. Dependabot can auto-create a PR to update the vulnerable package

Without this: you'd need to manually subscribe to security mailing lists and audit your `package.json` periodically. Almost no one does this consistently.

---

## Security Features Overview

```
Dependabot Alerts       → tells you when a dependency has a vulnerability
Dependabot Updates      → opens PRs to update dependencies automatically
Secret Scanning         → finds accidentally committed API keys, tokens
Code Scanning           → static analysis for code vulnerabilities (SAST)
Security Advisories     → managed disclosure process for your project
Branch Protection       → gates on what can merge to protected branches
```

---

## Dependabot — Automatic Dependency Management

### Dependabot Alerts (Free)

Enabled automatically on all public repos. For private repos: Settings → Security → Enable Dependabot alerts.

When a CVE is published for a package in your `package.json`:
```
GitHub notifies you:
  "Critical vulnerability found in dependency"
  Package: lodash 4.17.15
  Vulnerability: CVE-2021-23337 (Command Injection)
  Severity: Critical
  Fix available: Update to lodash 4.17.21
  
  [Review security advisory] [Dismiss alert]
```

### Dependabot Version Updates

Dependabot opens PRs to keep your dependencies up-to-date (not just security fixes — regular updates too).

```yaml
# .github/dependabot.yml
version: 2
updates:

  # npm dependencies
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly          # check every week
      day: monday
    open-pull-requests-limit: 10
    groups:                     # group minor updates into one PR
      minor-updates:
        update-types:
          - minor
          - patch
    ignore:
      - dependency-name: lodash  # skip lodash updates
        versions: [">=5.0.0"]    # skip major version bumps
    labels:
      - dependencies
      - automated

  # Docker base image
  - package-ecosystem: docker
    directory: /
    schedule:
      interval: weekly

  # GitHub Actions
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
```

**What Dependabot PRs look like:**

```
PR: Bump express from 4.18.2 to 4.21.0 (opened by dependabot[bot])

Release notes:
  express/express v4.19.0 ... v4.21.0
  - CVE-2024-29041: Fix open redirect vulnerability
  - Added support for async error handlers
  - Minor performance improvements

Changelog: [link]
Commits: [commit list]

Dependency files changed:
  package.json:  "express": "4.18.2" → "4.21.0"
  package-lock.json: [updated]

Compatibility: 100% (based on dependabot's analysis)
```

You review, merge the PR → dependency updated.

---

## Secret Scanning

### What It Detects

GitHub maintains a list of 150+ service providers' token formats (AWS, GitHub, Stripe, Twilio, etc.). Every push to your repo is scanned against these patterns.

```
What gets detected:
  AWS Access Key IDs:      AKIA[0-9A-Z]{16}
  AWS Secret Keys:         [pattern]
  GitHub Tokens:           ghp_[0-9A-Za-z]{36}
  Stripe API Keys:         sk_live_[0-9a-zA-Z]{24}
  Slack Bot Tokens:        xoxb-[0-9]{11}-[0-9]{11}-[0-9a-zA-Z]{24}
  Google API Keys:         AIza[0-9A-Za-z-_]{35}
  Twilio Account SID:      AC[0-9a-fA-F]{32}
  ... 150+ more patterns
```

### What Happens on Detection

```
Developer accidentally commits:
  const stripeKey = "sk_live_abcdef123456789...";

GitHub detects this:
  1. Notifies you via email and Security tab alert
  2. If configured: notifies Stripe directly to invalidate the key
     (Stripe will revoke the key before an attacker can use it)
  3. Creates a secret scanning alert in your repo
```

### Push Protection (Blocks the Push)

Enable to BLOCK pushes that contain secrets (not just alert after):

```
Settings → Security → Secret scanning → Push protection → Enable
```

```bash
# Developer tries to push a file with AWS key
git push origin feature/payment

remote: Resolving deltas: 100%
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote:
remote: — Push cannot contain secrets —
remote:
remote:   src/config.js:12: GitHub found a GitHub Personal Access Token.
remote:   Secret: ghp_xxxxxxxxxxxxxx
remote:
remote: To push, either:
remote:   - Remove the secret from your code and push again
remote:   - Allow the push for this secret if you believe it's not a real token
```

The push is rejected. Developer removes the secret, uses an environment variable instead, then pushes.

---

## Code Scanning (SAST — Static Application Security Testing)

Code scanning analyzes your source code for security vulnerabilities without running it.

### Enable with GitHub Actions (Free)

```yaml
# .github/workflows/codeql.yml
name: CodeQL Analysis

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * 1'    # weekly scan on Monday

jobs:
  analyze:
    name: Analyze
    runs-on: ubuntu-latest
    permissions:
      security-events: write    # needed to upload findings
      contents: read

    strategy:
      matrix:
        language: ['javascript']    # or python, java, go, ruby, cpp

    steps:
    - uses: actions/checkout@v4

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v3
      with:
        languages: ${{ matrix.language }}

    - name: Autobuild
      uses: github/codeql-action/autobuild@v3

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v3
```

### What CodeQL Finds

```
Security findings appear in: Security → Code scanning alerts

Example alerts:

  HIGH: SQL injection possible
  File: src/services/userService.js:145
  Code: db.query(`SELECT * FROM users WHERE email = '${email}'`)
  Explanation: User-controlled data flows into SQL query without sanitization
  Fix: Use parameterized queries

  MEDIUM: Prototype pollution possible
  File: src/utils/merge.js:23
  Code: Object.assign(target, userInput)
  Explanation: User input merged into object without filtering __proto__

  LOW: Regular expression injection
  File: src/search.js:67
  Code: new RegExp(searchTerm)
```

### Third-Party Scanners in GitHub

Not just CodeQL — many scanners integrate with GitHub Code Scanning:

```yaml
# Trivy (container + filesystem scanning)
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy scan results to GitHub Security tab
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'
```

All findings appear in the same Security tab, regardless of which scanner found them.

---

## Branch Protection Rules — Gates for Main

Branch protection prevents accidents and enforces your team's standards.

```
Settings → Branches → Add branch protection rule
Branch name pattern: main

Protect matching branches:
  ✓ Require a pull request before merging
    Required approvals: 2
    ✓ Dismiss stale pull request approvals when new commits are pushed
    ✓ Require review from Code Owners
    
  ✓ Require status checks to pass before merging
    Status checks:
      test (node 18)
      test (node 20)
      build
      security-scan
      lint
    ✓ Require branches to be up to date before merging
    
  ✓ Require conversation resolution before merging
  
  ✓ Require signed commits
  
  ✓ Include administrators
  
  ✗ Allow force pushes     (disabled — protect history)
  ✗ Allow deletions        (disabled — protect the branch)
```

With these rules:
- No one can push directly to `main` (even admins, if "Include administrators" is on)
- PRs need 2 approvals
- All CI checks must pass
- Code owners must review relevant files
- No force pushes

A junior developer can't accidentally `git push --force main` and destroy history.

---

## CODEOWNERS — Automatic Review Requests

When a PR touches files you own, you're automatically added as a required reviewer.

```
# .github/CODEOWNERS

# Default owners for everything
*                   @your-org/tech-leads

# Backend: backend team must review
/src/api/           @your-org/backend-team
/src/services/      @your-org/backend-team
/migrations/        @your-org/backend-team @your-org/dba-team

# Frontend: frontend team must review
/src/components/    @your-org/frontend-team
/src/pages/         @your-org/frontend-team

# Infrastructure: DevOps must review
/.github/workflows/ @your-org/devops-team
/helm/              @your-org/devops-team
/terraform/         @your-org/devops-team

# Security-sensitive files: security team required
/src/middleware/auth.js    @security-lead
/src/utils/crypto.js       @security-lead
```

When someone opens a PR that changes `/helm/charts/vault-api/`, GitHub automatically requests a review from `@your-org/devops-team`. They can't merge without that approval.

---

## Security Advisories — Responsible Disclosure

When a vulnerability is found in your project, Security Advisories let you:
1. Work on the fix privately (without publicizing the vulnerability)
2. Coordinate with the reporter
3. Publish the advisory when the fix is ready

```
Security → Advisories → New draft security advisory

Fill in:
  Ecosystem: npm
  Package name: your-package
  Affected versions: <1.3.0
  Patched version: 1.3.0
  Severity: High
  Description: [full write-up of the vulnerability]
  CVSS Score: (auto-calculated)
  
GitHub assigns a CVE number when published.
```

This is the industry-standard responsible disclosure process. You see these in open-source npm packages: `SECURITY.md` describes how to report, advisories show the history.

---

## Common Misunderstanding: "Security features only matter for open source"

**The misunderstanding:** "We're a private repo, so secret scanning and code scanning don't matter."

**The reality:** Private repos are MORE at risk from:
- Accidentally committed API keys (secret scanning is critical for private internal tools)
- Stale vulnerable dependencies (you may not have the same scrutiny as public OSS)
- Security vulnerabilities in internal APIs (CodeQL still matters)
- Force pushes to main (branch protection still matters)

The one difference: with a public repo, the whole world can see your vulnerabilities. With private: only insiders. But insider threats and accidental commits happen regardless of visibility.

Enable all security features on private repos too. They're mostly free, and the one time they catch a real issue justifies the 5 minutes of setup.

→ Continue to: `23-github-actions-all-use-cases.md`
